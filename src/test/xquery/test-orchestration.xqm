module namespace test = 'http://basex.org/modules/xqunit-tests';

import module namespace orch="http://basex-orchestration.org/xquery/module/orchestration";
import module namespace dbadmin="http://basex-orchestration.org/xquery/module/database-admin";
import module namespace logging="http://basex-orchestration.org/xquery/module/logging";


declare namespace xqdoc="http://www.xqdoc.org/1.0";

declare variable $test:database := string('test_' || '01');
declare variable $test:swappedFrom := 'test_swapped_from';
declare variable $test:swappedTo := 'test_swapped_to';
declare variable $test:dbs as xs:string* := ('db1', 'db2', 'db3');


declare %unit:before-module updating function test:setUp() {
(
  if (db:exists($test:database))
  then (
    update:output(prof:dump('test:setUp(): Dropping database ' || $test:database)),
    db:drop($test:database)
  ),
  if (db:exists($test:swappedFrom))
  then (
    update:output(prof:dump('test:setUp(): Dropping database ' || $test:swappedFrom)),
    db:drop($test:swappedFrom)
  ),
  if (db:exists($test:swappedTo))
  then (
    update:output(prof:dump('test:setUp(): Dropping database ' || $test:swappedTo)),
    db:drop($test:swappedTo)
  ),
  for $database in $test:dbs
  return
  if (db:exists($database))
  then db:drop($database)
  else ()
  ,
  dbadmin:cleanupBackupDatabases()
)
};

declare %unit:after-module updating function test:tearDown() {
  update:output(prof:dump('test:tearDown(): Dropping database ' || $test:database)),
  if (db:exists($test:database)) 
  then 
    try {
      db:drop($test:database)
    } catch * {
      update:output(prof:dump('test:tearDown(): Error ' || $err:code || ' from db:drop(): ' || $err:description))    
    }
  else update:output("test:tearDown(): Database " || $test:database || " does not exist.")
};

declare %unit:test function test:createJob() {
  let $moduleNamespace := "http://basex-orchestration.org/xquery/module/database-admin"
  let $funcName := 'dbadmin:createDatabase'
  let $parms as xs:string* := ($test:database)
  let $job as xs:string := orch:makeJob($moduleNamespace, $funcName, $parms)
  (: xquery:parse() will fail if the job is not a valid XQuery :)
  let $plan as item()? := xquery:parse($job)
  return (
    unit:assert(contains($job, 'dbadmin:createDatabase(''' || $test:database || ''')'), 'Did not match expected.')
  )
};

declare %unit:test function test:createBadJob() {
  let $moduleNamespace := "http://basex-orchestration.org/xquery/module/database-admin"
  let $funcName := 'createDatabase'
  let $parms as xs:string* := ('parm1', 'parm2')
  let $error as item()* :=
  try {
    orch:makeJob($moduleNamespace, $funcName, ($test:database))
  } catch * {
    $err:code, $err:description
  } 
  let $debug := prof:dump(($error))
  return (
    unit:assert-equals(
      ($error[1]),
      QName("http://basex-orchestration.org/xquery/module/orchestration",'orch:JOB001'),
      'Did not get expected error code JOB001'
    )
  )
};

declare  %unit:before("test:runJobs1") updating function  test:beforeRunJobs1() {
  if (db:exists($test:database))
  then db:drop($test:database)
  else ()
};

declare %unit:after("test:runJobs1") function  test:afterRunJobs1() {
  (
    prof:dump('test:afterRunJobs1(): Waiting 1 seconds...'),
    unit:assert(db:exists($test:database), 'Expected database ' || $test:database || ' to exist')
  )
};

declare  %unit:test function test:runJobs1() {
  let $moduleNamespace := "http://basex-orchestration.org/xquery/module/database-admin"
  let $funcName := 'dbadmin:createDatabase'
  let $parms as xs:string* := ($test:database)
  let $noDb as xs:boolean := db:exists($test:database)
  let $job1 as xs:string := orch:makeJob($moduleNamespace, $funcName, $parms)
  let $jobs as map(*)* := orch:runJobs(($job1))
  return (
    unit:assert(exists($jobs), 'Expected a result'),
    unit:assert-equals(count($jobs), 1, 'Expected 1 job')
  )  
};

declare %unit:before("test:runJobs2") updating function  test:beforeRunJobs2() {
  if (not(db:exists($test:database)))
  then db:create($test:database)
  else ()
};

declare %unit:after("test:runJobs2") function  test:afterRunJobs2() {
  (
  prof:dump('test:afterRunJobs2(): Waiting 1 seconds...'),
  unit:assert(not(db:exists($test:database)), 'Expected database ' || $test:database || ' to not exist')
)
};

declare  %unit:test function test:runJobs2() {
  let $moduleNamespace := "http://basex-orchestration.org/xquery/module/database-admin"
  let $funcName := 'dbadmin:createDatabase'
  let $parms as xs:string* := ($test:database)
  let $job2 as xs:string := orch:makeJob($moduleNamespace, 'dbadmin:dropDatabase', $parms)
  let $jobs as map(*)* := orch:runJobs(($job2))
  return (
    unit:assert(exists($jobs), 'Expected a result'),
    unit:assert-equals(count($jobs), 1, 'Expected 1 job')
  )  
};

declare %unit:after("test:runMultipleJobs") function  test:afterRunMultipleJobs() {
  (
    for $database in $test:dbs
    return
    unit:assert(db:exists($database), 'Expected database ' || $database || ' to exist')
  )
};


declare  %unit:test function test:runMultipleJobs() {
  let $jobs as xs:string* := (
    for $database in $test:dbs
    return dbadmin:makeJob('dbadmin:createDatabase', $database)
  )
  let $jobs as map(*)* := orch:runJobs($jobs)
  return
  (
    prof:dump('jobs'), prof:dump($jobs),
    unit:assert-equals(count($jobs), 3, 'Expected 3 job IDs')
  )
};

declare %unit:before("test:runSwapJobs") updating function  test:beforeRunSwapJobs() {
  let $doc1 as element() := <doc id="doc1">Doc 1</doc>
  let $docPath1 as xs:string := 'doc1.xml'
  let $doc2 as element() := <doc id="doc2">Doc 2</doc>
  let $docPath2 as xs:string := 'doc2.xml'
  return
  (
    (: Swapped to is the "production" database :)
    if (not(db:exists($test:swappedTo)))
    then db:create($test:swappedTo, $doc1, $docPath1)
    else db:replace($test:swappedTo, $docPath1, $doc1)
    ,
    (: Swapped from is the "temp" database, where stuff is added :)
    if (not(db:exists($test:swappedFrom)))
    then db:create($test:swappedFrom, $doc2, $docPath2)
    else db:replace($test:swappedFrom, $docPath2, $doc2)
    (: After the swap, doc2 should be the "production" document in db $swappedTo :)
  )
};

declare %unit:after("test:runSwapJobs") function  test:afterRunSwapJobs() {
  (
    let $doc2 := collection($test:swappedTo || '/doc2.xml')
    return
    unit:assert(exists($doc2), 'Expected to find doc2 in database ' || $test:swappedTo)
  )
};

declare %unit:test function test:runSwapJobs() {
  let $moduleNamespace := "http://basex-orchestration.org/xquery/module/database-admin"
  let $jobs as xs:string* := dbadmin:makeSwapJobs($test:database, 'test_swapped_to')
  let $jobs as map(*)* := orch:runJobs($jobs)
  return (
    unit:assert(exists($jobs), 'Expected a result'),
    unit:assert-equals(count($jobs), 3, 'Expected 3 jobs')
  )  
};

declare %unit:test function test:makeJobsFromModules() {
  let $moduleNamespace := "http://basex-orchestration.org/xquery/module/database-admin"
  let $funcName := 'dbadmin:createDatabase'
  let $parms as xs:string* := ($test:database)
  let $jobs as xs:string* := 
    (
      dbadmin:makeJob($funcName, $parms),
      dbadmin:makeJob($funcName, $parms)
    )
  return (
    unit:assert-equals(count($jobs), 2, 'Expected two jobs'),
    unit:assert(matches($jobs[1], '^\s*import module namespace dbadmin="' || $moduleNamespace || '";'), 
      'Expected import module, have ''' || $jobs[1] || '''')
  )
};

declare %unit:test function test:makeSwapJobs() {
  let $jobs as xs:string* := dbadmin:makeSwapJobs($test:database, dbadmin:makeBackupDatabaseName($test:database))
  return (
    unit:assert-equals(count($jobs), 3, 'Expectd 3 jobs, got ' || count($jobs))
  )
};

