using 'main.bicep'

// No secrets belong in this file -- there's nothing secret to parameterize
// given the connection-string-via-listConnectionStrings() design (Security.md #1).
// Every param in main.bicep already has a sensible default (location, region,
// app name), so no explicit assignments are needed here -- this file exists
// only to satisfy Bicep's required `using` declaration.
