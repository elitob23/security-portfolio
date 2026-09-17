#event_simpleName=OsVersionInfo
| event_platform=Win
| BuildNumber=26100
| groupBy([aid, ComputerName], function=count(as=EventCount))