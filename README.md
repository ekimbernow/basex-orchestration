# BaseX Orchestration Package

Provides a set of functions for managing the creation of BaseX jobs that run functions from other modules. The orchestration infrastructure runs sequences of jobs in order to perform separate transactions.

Each job is constructed as an XQuery that runs the specified function from the specified module with zero or more string parameters.

The implementing module is `src/main/xquery/modules/orchestration.xqm`, which provides functions for constructing and then running jobs. The `database-admin.xqm` module included with this project serves as an example of how to use functions from other modules as jobs and provides a set of convenience functions for manipulating BaseX databases (create, drop, copy, rename, etc.).

The primary orchestration functions are:

* `orch:makeJob()`: Takes a function name, namespace URI, and list of parameter values and constructs an XQuery that runs the function with the parameters. The constructed query also takes as input a sequence of "job maps" that provide the follow-on jobs to be run after the query completes its work. The query uses job:eval() to run the next job in the sequence, if there is one.
* `orch:runJobs()`: Takes a sequence of XQueries as created by `orch:makeJob()`, prepares them for running, and then runs the sequence by queueing the first job.
* `orch:writeJobsToFiles()`: Writes a sequence of job XQueries to disk. Useful for inspecting the constructed jobs.

XQuery modules can implement their own `makeJob()` functions that statically set the namespace URI, i.e., this example from the included `database-admin.xqm` module:

```
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
```

Modules can also provide functions that construct sets of related jobs that perform a repeated task, such as the `dbadmin:makeSwapJobs()` function:

```
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
```

These job-making functions then make it easy to compose sets of actions together to form a larger task.

The included `logging.xqm` module provides logging utilities for logging both non-updating actions (`logging:logTolog()`) and updating activities (`logging:logToConsole()`). The `logToLog()` function just uses `prof:dump()`, while `logToConsole()` usese both `prof:dump()` and `update:output()` so that messages from updates go to the primary console as well as to the debugging log.

