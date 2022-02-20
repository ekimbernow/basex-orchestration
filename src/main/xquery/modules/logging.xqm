(:~ 
 : Utilities for logging in various ways.
 :)
module namespace util="http://basex-orchestration.org/xquery/module/logging";

declare namespace xqdoc="http://www.xqdoc.org/1.0";

(:~ 
 : Puts the specified message to the log (prof:dump()).
 : Uses "info" log level.
 : @param functionName The name of the function the message applies to
 : @param message The message text
 : @return Formats the message and puts it to both the trace log and console output
 :)
declare function util:logToLog(
  $message as xs:string
) {
  let $context as item()* := inspect:context()
  (: let $debug := (prof:dump('logToLog(): inspect:context is:'), prof:dump($context)) :)
  let $caller as xs:string := $context/function[last()]/@name ! string(.)
  return util:logToLog($caller, $message)
}; 

(:~ 
 : Puts the specified message to both the console (update:output()) and the log (prof:dump()).
 : Uses "info" log level.
 : @param functionName The name of the function the message applies to
 : @param message The message text
 : @return Formats the message and puts it to both the trace log and console output
 :)
declare function util:logToLog(
  $functionName as xs:string,
  $message as xs:string) {
  util:logToLog($functionName, $message, 'info')
}; 

(:~ 
 : Puts the specified message to both the console (update:output()) and the log (prof:dump())
 : @param functionName The name of the function the message applies to
 : @param message The message text
 : @param logLevel The log level (debug, info, warn, error, fatal)
 : @return Formats the message and puts it to both the trace log and console output
 :)
declare function util:logToLog(
  $functionName as xs:string,
  $message as xs:string,
  $logLevel as xs:string
) {
  let $logMessage as xs:string := '[' || upper-case($logLevel) || '] ' || $functionName || '(): ' || $message
  return
  (
    prof:dump($logMessage)
  )  
};

(:~ 
 : Puts the specified message to both the console (update:output()) and the log (prof:dump()).
 : Uses "info" log level.
 : NOTE: update:output() messages are part of the update queue so they may not be emitted until
 :       any following updates complete, so they are mostly informational.
 : @param functionName The name of the function the message applies to
 : @param message The message text
 : @return Formats the message and puts it to both the trace log and console output
 :)
declare updating function util:logToConsole(
  $message as xs:string
) {
  let $caller as xs:string := inspect:context()/function[last()]/@name ! string(.)
  return util:logToConsole($caller, $message)
}; 

(:~ 
 : Puts the specified message to both the console (update:output()) and the log (prof:dump()).
 : Uses "info" log level.
 : NOTE: update:output() messages are part of the update queue so they may not be emitted until
 :       any following updates complete, so they are mostly informational.
 : @param functionName The name of the function the message applies to
 : @param message The message text
 : @return Formats the message and puts it to both the trace log and console output
 :)
declare updating function util:logToConsole(
  $functionName as xs:string,
  $message as xs:string) {
  util:logToConsole($functionName, $message, 'info')
}; 

(:~ 
 : Puts the specified message to both the console (update:output()) and the log (prof:dump())
 : NOTE: update:output() messages are part of the update queue so they may not be emitted until
 :       any following updates complete, so they are mostly informational.
 : @param functionName The name of the function the message applies to
 : @param message The message text
 : @param logLevel The log level (debug, info, warn, error, fatal)
 : @return Formats the message and puts it to both the trace log and console output
 :)
declare updating function util:logToConsole(
  $functionName as xs:string,
  $message as xs:string,
  $logLevel as xs:string
) {
  let $logMessage as xs:string := '[' || upper-case($logLevel) || '] ' || $functionName || '(): ' || $message
  return
  (
    update:output(prof:dump($logMessage)),
    update:output($logMessage)
  )  
};
