# ai-usage

A CQL query that shows which users and hosts are reaching major generative AI services from Windows endpoints, based on Falcon DNS telemetry.

Query file: [`aiusage.cql`](aiusage.cql)

## Purpose

Organizations adopting AI usage policies usually need to answer a basic question first: *who is actually using these tools, and which ones?* This query gives a quick inventory of AI service access without a proxy or CASB, using only data the Falcon sensor already collects.

Typical uses:

- Measuring AI adoption across the fleet before writing or enforcing a policy
- Finding use of AI services that aren't sanctioned
- Following up on data-handling concerns for a specific user or host
- Spotting non-browser processes (scripts, CLIs, desktop apps) calling AI APIs

## Services covered

| AIService label    | Domains matched                                                              |
|--------------------|------------------------------------------------------------------------------|
| ChatGPT/OpenAI     | `openai.com`, `chatgpt.com`, `chat.openai.com`                               |
| Google Gemini      | `gemini.google.com`, `bard.google.com`, `generativelanguage.googleapis.com`  |
| Claude/Anthropic   | `claude.ai`, `anthropic.com`                                                 |
| DeepSeek           | `deepseek.com`, `chat.deepseek.com`                                          |

Matching is case-insensitive, and subdomains are included (for example, `api.openai.com`).

## How it works

The query finds Windows `DnsRequest` events for AI service domains. It joins them to `ProcessRollup2` to find the process that made each request, then to `UserIdentity` to get the username. Results are grouped by host, user and service, and sorted by request count.

For a block-by-block walkthrough, see [`howitworks.txt`](howitworks.txt).

## Output

| Field                 | Description                                         |
|-----------------------|-----------------------------------------------------|
| `aid`                 | Falcon agent ID                                     |
| `ComputerName`        | Endpoint hostname                                   |
| `FinalUserName`       | Resolved user, or the process name as a fallback    |
| `LogonDomain`         | Domain of the resolved user                         |
| `AIService`           | Service category                                    |
| `RequestCount`        | Number of matching DNS requests                     |
| `DomainName`          | Up to 10 distinct domains queried                   |
| `ContextBaseFileName` | Up to 10 process names that made the requests       |
| `ImageFileName`       | Up to 10 full image paths from `ProcessRollup2`     |

## Usage

1. Open **Next-Gen SIEM → Advanced event search** in Falcon.
2. Paste in the contents of `aiusage.cql`.
3. Set a time range when you run the search. The query doesn't set one. Start with 24 hours or 7 days, because the joins get expensive over long windows.

To add a service, add its domain to the `DomainName` filter regex and add a matching branch to the first `case` block.

## Limitations and tuning

- **A DNS lookup doesn't prove someone used the service.** Link previews, browser prefetching, embedded widgets, and documentation pages can all trigger lookups. Treat low `RequestCount` values as noise until you check them.
- **Cached lookups are missed.** If the OS or browser has already cached a domain, or the browser uses DNS-over-HTTPS, no new `DnsRequest` event is logged. Counts are a lower bound.
- **Domain matching is broad.** The regex isn't anchored, so it also matches domains that only *contain* a listed name. To tighten it, anchor each pattern, for example `/(^|\.)openai\.com$/i`.
- **`anthropic.com` includes non-product traffic.** Marketing and docs pages fall under the Claude/Anthropic label. To count only product use, narrow the pattern to `claude.ai` and `api.anthropic.com`.
- **Join limits.** CQL `join()` subqueries have row limits. In large environments or long time ranges, some process or user context may be dropped silently, so more rows show a fallback `FinalUserName`.
- **Windows only.** macOS and Linux endpoints are excluded by `event_platform=Win`.
- **Coverage gaps.** Services not in the list, such as Microsoft Copilot, Perplexity, Mistral, and Hugging Face, won't appear.

## Status

Completed
