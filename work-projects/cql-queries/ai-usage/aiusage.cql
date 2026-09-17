// Identify users accessing major AI services on Windows endpoints
// Using DnsRequest events and joining with process context for username resolution

#event_simpleName=DnsRequest event_platform=Win
// Filter for major AI service domains
| DomainName=/openai\.com|chatgpt\.com|chat\.openai\.com|gemini\.google\.com|bard\.google\.com|generativelanguage\.googleapis\.com|claude\.ai|anthropic\.com|deepseek\.com|chat\.deepseek\.com/i
// Categorize the AI service
| case {
    DomainName=/openai\.com|chatgpt\.com/i | AIService:="ChatGPT/OpenAI";
    DomainName=/gemini|bard|generativelanguage\.googleapis/i | AIService:="Google Gemini";
    DomainName=/claude\.ai|anthropic\.com/i | AIService:="Claude/Anthropic";
    DomainName=/deepseek\.com/i | AIService:="DeepSeek";
    * | AIService:="Other AI Service";
  }
// Join with ProcessRollup2 to get username context when DnsRequest lacks it
| join({#event_simpleName=ProcessRollup2 event_platform=Win | rename(field=TargetProcessId, as=ContextProcessId)}, field=ContextProcessId, key=ContextProcessId, include=[UserSid, CommandLine, ImageFileName], mode=left)
// Now join with UserIdentity to resolve UserSid to UserName
| join({#event_simpleName=UserIdentity | rename(field=UserName, as=ResolvedUserName)}, field=UserSid, key=UserSid, include=[ResolvedUserName, LogonDomain], mode=left)
// Create a final username field prioritizing resolved username
| case {
    ResolvedUserName=* | FinalUserName:=ResolvedUserName;
    ContextBaseFileName=* | FinalUserName:=format("Process: %s", field=[ContextBaseFileName]);
    * | FinalUserName:="Unknown";
  }
// Format timestamp for readability
| formatTime(field=@timestamp, format="%Y-%m-%d %H:%M:%S", as=Timestamp)
// Select and display relevant fields
| groupBy([aid, ComputerName, FinalUserName, LogonDomain, AIService], function=[count(as=RequestCount), collect([DomainName, ContextBaseFileName, ImageFileName], limit=10)])
| sort(RequestCount, order=desc, limit=1000)
