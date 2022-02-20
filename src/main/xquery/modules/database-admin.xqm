(:~ 
 : Functions for managing the databases used by the Validation Dashboard system.
 :
 : This includes creating, copying, and removing temp and production databases, managing
 : database backup, and other administrative tasks for databases.
 :)

module namespace dbadmin="http://basex-orchestration.org/xquery/module/database-admin";

import module namespace orch="http://basex-orchestration.org/xquery/module/orchestration";
import module namespace logging="http://basex-orchestration.org/xquery/module/logging";

(:~ 
 : Prefix to use for backup copies of databases created during swap operations.
 :)
declare variable $dbadmin:backupPrefix as xs:string := '_backup';

(:~ 
 : Prefix to use for temp copies of databases created for long-running processes.
 :)
declare variable $dbadmin:tempPrefix as xs:string := '_temp';
 
(:~ 
 : Creates the requested database if it does not already exist.
 : @param database The name of the database to create
 : @return The database is created if it does not already exist
 : @throws dbadmin:DB0001 : Target database exists
 :)
declare updating function dbadmin:createDatabase($database as xs:string) {
  if (not(db:exists($database)))
  then 
  (
    update:output(prof:dump('Creating database ' || $database)),
    try {
      db:create($database)
    } catch * {
      
    }
  )
  else error(
    QName('http://basex-orchestration.org/xquery/module/database-admin', 'DB0001'), 
    'Database creation target ''' || $database || ''' already exists', 
    $database)
};

(:~ 
 : Construct a backup database name for a database
 : @param database The database to make the backup name for
 : @return The name to use as the backup database name
 :)
declare function dbadmin:makeBackupDatabaseName($database as xs:string) as xs:string {
  let $rando := random-number-generator()?number ! string(.) ! substring-after(., '.')  
  let $backup := string-join(($dbadmin:backupPrefix, $database, $rando), '_')
  return $backup
}; 

(:~ 
 : Create a backup copy of a database (NOTE: This is not the same as using BaseX
 : to back up a database).
 : @param database Name of the database to make a backup copy of
 : @return Creates the backup database
 :)
declare updating function dbadmin:makeBackupDatabase($database as xs:string) {
  let $backup as xs:string := dbadmin:makeBackupDatabaseName($database)
  return 
  if (db:exists($database))
  then dbadmin:copyDatabase($database, $backup)
  else logging:logToConsole(
    'dbadmin:makeBackupDatabase', 
    'Database ''' || $database || ''' does not exist. Nothing to back up.')
}; 

(:~ 
 : Renames a database to its back up name (in preparation for swapping a temporary
 : database into its place, usually)
 : @param database Name of the database to move to a backup name
 : @return Creates the backup database
 :)
declare updating function dbadmin:renameToBackup($database as xs:string) {
    let $timeMillis := prof:current-ms() ! string(.)
    let $backup := string-join(($dbadmin:backupPrefix, $database, $timeMillis), '_')
    return dbadmin:renameDatabase($database, $backup)
}; 

(:~ 
 : Clean up backup databases
 : @return Removes all databases that start with the backup prefix name
 :)
declare updating function dbadmin:cleanupBackupDatabases() {
  let $databases as xs:string* := db:list()
  let $debug := prof:dump('dbadmin:cleanupBackupDatabases(): Dropping backup databases')
  return
  for $database in dbadmin:getBackupDatabases()
  return 
  dbadmin:dropDatabase($database)  
};

(:~ 
 : Get the names of any backup databases
 : @return List, possibly empty, of backup databsase names.
 :)
declare function dbadmin:getBackupDatabases() as xs:string* {
  for $database in db:list()
  where starts-with($database, $dbadmin:backupPrefix)
  return $database
};

(:~ 
 : Copy the "from" database to new database "to"
 : @param from The database to be copied
 : @param to The name of the database to copy to
 : @return Copies the "from" datbase to the "to" database if the "to"
 : database does not already exist.
 : @throws dbadmin:DB0001 : Target database exists
 :)
declare updating function dbadmin:copyDatabase(
  $from as xs:string,
  $to as xs:string
) {
  if (not(db:exists($to)))
  then 
  (    
    update:output(prof:dump('Copying ' || $from || ' to ' || $to)),
    try {
      db:copy($from, $to)
    } catch * {
      update:output(prof:dump('dbadmin:copyDatabase(): Exception copying database ''' || $from || ''': ' || $err:code || ' - ' || $err:description))
    }
  )
  else error(
    QName('http://basex-orchestration.org/xquery/module/database-admin', 'DB0001'), 
    'Database copy target ''' || $to || ''' already exists', 
    $to)
};

(:~ 
 : Rename the "from" database to new name "to"
 : @param from The database to be renamed
 : @param to The name to rename the "from" database to
 : @return Renames the "from" datbase to the "to" name if the "to"
 : database does not already exist.
 : @throws dbadmin:DB0001 : Target database exists
 :)
declare updating function dbadmin:renameDatabase(
  $from as xs:string,
  $to as xs:string
) {
  if (not(db:exists($to)))
  then 
   (
    update:output(prof:dump('Renaming ' || $from || ' to ' || $to)),
    try {
      db:alter($from, $to)
    } catch * {
      update:output(prof:dump('dbadmin:renameDatabase(): Exception renaming database ''' || $from || ''': ' || $err:code || ' - ' || $err:description))
    }
   )
  else error(
    QName('http://basex-orchestration.org/xquery/module/database-admin', 'DB0001'), 
    'Database rename target ''' || $to || ''' already exists', 
    $to)
};

(:~ 
 : Drops (deletes) the specified database
 : NOTE: This is destructive action that cannot be undone unless there is a backup
 : or backup copy (in BaseX) of the database.
 : @param from The database to be dropped
 : @return Drops the database
 :)
declare updating function dbadmin:dropDatabase(
  $database as xs:string
) {
   try {
     if (db:exists($database))
     then 
     (
       logging:logToConsole('dbadmin:dropDatabase', ``[Dropping database '`{$database}`]``),
       db:drop($database)
     )
     else logging:logToConsole('dbadmin:dropDatabase', ``[Database '`{$database}`' does not exist. Nothing to drop.]``)
   } catch * {
     logging:logToConsole(
       'dbadmin:dropDatabase', 
       ``[Exception dropping database '`{$database}`: `{$err:code}` - `{$err:description}`]``,
       'error')
   }

};

(:~ 
 : Make the sequence of jobs that will swap database from to database to.
 : @param from The starting database (i.e., a temporary link record keeping database)
 : @param to The database to swap to.
 : @return Sequence of job strings that implement the necessary actions to effect the swap.
 :)
declare function dbadmin:makeSwapJobs($from as xs:string, $to as xs:string) as xs:string* {
  (
    dbadmin:makeJob('dbadmin:makeBackupDatabase', $to),
    dbadmin:makeJob('dbadmin:dropDatabase', $to),
    dbadmin:makeJob('dbadmin:renameDatabase', ($from, $to))
  )
};

(:~ 
 : Constructs an XQuery that will run the specified function with no parameters.
 : @return An XQuery string suitable for running with job:eval() or xquery:eval()
 :)
declare function dbadmin:makeJob($funcName as xs:string) {
  dbadmin:makeJob($funcName, ())
};

(:~ 
 : Constructs an XQuery that will run the specified function with the specified
 : string parameters.
 : @param parms Parameter values. Each value will be passed to the function as a quoted string.
 : @return An XQuery string suitable for running with job:eval() or xquery:eval()
 :)
declare function dbadmin:makeJob(
  $funcName as xs:string,
  $parms as xs:string*
) as xs:string {
  orch:makeJob(
    'http://basex-orchestration.org/xquery/module/database-admin',
    $funcName,
    $parms)
};
