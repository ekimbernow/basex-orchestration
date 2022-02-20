(:~ 
 : Functions for orchestrating the management and operation of the system.
 :
 : These functions cut across database admin, validation reporting, link management
 : etc. Each module provides job-making functions for its concerns and this 
 : module composes those jobs into complete coordinated operations.
 :
 : Uses the BaseX jobs module to run sets of updating operations.
 :
 :)

module namespace orch="http://basex-orchestration.org/xquery/module/orchestration";

import module namespace dbadmin="http://basex-orchestration.org/xquery/module/database-admin";
import module namespace logging="http://basex-orchestration.org/xquery/module/logging";

(:~ 
 : Constructs an XQuery that will run the specified function in the specified module with the specified
 : string parameters to be used as a job with the orch:runJobs() function.
 : @param moduleNamespace The namespace URI of the module the function is in.
 : @param funcName The name of the function to run in the specified module. The namespace
 :                 prefix on the function name will be used as the module namespace prefix.
 : @param parms Parameter values. Each value will be passed to the function as a quoted string.
 : @return An XQuery string suitable for running with job:eval() or xquery:eval()
 :)
declare function orch:makeJob(
  $moduleNamespace as xs:string,
  $funcName as xs:string,
  $parms as xs:string*
) as xs:string {
  let $tokens := tokenize($funcName, ':')
  return
  if (count($tokens) lt 2)
  then error(QName('http://basex-orchestration.org/xquery/module/orchestration','orch:JOB001'), 
             'Function name ''' || $funcName || ''' must include a namespace prefix')
  else
  let $nsprefix as xs:string := $tokens[1]
  return
``[
import module namespace `{$nsprefix}`="`{$moduleNamespace}`";
import module namespace orch="http://basex-orchestration.org/xquery/module/orchestration";

declare variable $jobs as map(*)* external := ();

let $nextJob as map(*)? := head($jobs)
return
(
  (: Run the job and then queue the next one, if there is one :)
  `{$funcName}`(`{ "'" || string-join($parms, "', '") || "'"}`),
  if (exists($nextJob))
  then
    let $jobID :=
      jobs:eval(
        $nextJob('job'),
        map{
          'jobs' : tail($jobs)
        },
        map {
          'id' : $nextJob('jobid'),
          'log' : 'Job ' || $nextJob('jobid')
        }
      )
    return()
  else ()
)
]``
};

(:~
 : Prepares a list of job maps from XQuery strings
 : @param jobs List of jobs 
 : @return Sequence of job maps 
 :)
declare function orch:prepareJobs($jobs as xs:string*) as map(*)* {
  for $job at $i in $jobs
  return
  map {
    'jobid' : 'orch:job' || $i || '_' || prof:current-ms(),
    'job' : $job
  }
}; 

(:~ 
 : Runs a sequence of jobs as separate transactions. The jobs are run immediately
 : (not queued).
 : @param jobs as xs:string* The jobs to run, as constructed by dbadmin:makeJob()
 : @return Runs the jobs and returns the IDs of the jobs that were run. The jobs
 :         will have finished. Use the job ID to retrieve any cached value for 
 :         the job.
 :)
declare function orch:runJobs($jobs as xs:string*) as map(*)* {
  let $jobMaps as map(*)* := orch:prepareJobs($jobs)
  return orch:runJobMaps($jobMaps)    
};

(:~ 
 : Runs a sequence of job maps
 : @param jobMaps Sequence of job maps
 : @return Queues the first job in the sequence and returns the set of job maps.
 :)
declare function orch:runJobMaps($jobMaps as map(*)*) as map(*)* {
  let $debug := (prof:dump('jobMaps:'), prof:dump($jobMaps))
  (: Schedule the first job: :)
  let $jobID :=
    jobs:eval(
      head($jobMaps)('job'),
      map{
        'jobs' : tail($jobMaps)
      },
      map {
        'id' : head($jobMaps)('jobid'),
        'log' : 'Job ' || head($jobMaps)('jobid')
      }
    )
  return $jobMaps  
}; 

(:~ 
 : Write the specified jobs to files in the specified directory
 : @param directory File system directory to write to
 : @param jobs The jobs to write
 : @return Writes the jobs to files in the specified directory and returns the filenames written to
 :)
declare function orch:writeJobsToFiles($directory as xs:string, $jobs as xs:string*) as xs:string* {
  orch:writeJobMapsToFiles($directory, orch:prepareJobs($jobs))
}; 

(:~ 
 : Write the specified job mapss to files in the specified directory
 : @param directory File system directory to write to
 : @param jobMaps The job maps to write
 : @return Writes the jobs to files in the specified directory and returns the filenames written to
 :)
declare function orch:writeJobMapsToFiles($directory as xs:string, $jobMaps as map(*)*) as xs:string* {
  let $makeDir := file:create-dir($directory)
  return
  for $job in $jobMaps
  let $filePath as xs:string := string-join(($directory, $job('jobid') || '.xqy'), '/')
  let $doWrite := file:write($filePath, $job('job'))
  return $filePath
}; 