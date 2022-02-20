# BaseX Orchestration Package

Provides a set of functions for managing the creation of BaseX jobs that run functions from other modules. The orchestration infrastructure runs sequences of jobs in order to perform separate transactions.

## Overview

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

The unit test script `src/test/xquery/test-orchestration.xqm` exercises the orchestration and demonstrates how to construct and run jobs.

Run the tests using the BaseX `TEST` command:

```
test /Users/eliot.kimber/git/basex-orchestration/src/test/xquery/test-orchestration.xqm
```

Note that as of 20 Feb 2022 and BaseX 9.6.4 the tests do not all pass because the jobs are not run until the test script itself is run, so the expected results are not available to the after-test functions that look for expected changes (i.e., databases that have been created, dropped, renamed, etc.).

## Building

To deploy the modules to BaseX, run the Ant script `src/main/build.xml`. The default target creates a BaseX module package and deploys it to BaseX.

To configure the deployment, create the file `.build.properties` in either the `src/main` directory or in your home directory and set the following properties:

```
basex.home.dir=/Users/eliot.kimber/apps/basex
basex.repo.dir=/Users/eliot.kimber/apps/basex/repo
```

Reflecting the location where you have BaseX installed or have configured its `repo/` directory.

