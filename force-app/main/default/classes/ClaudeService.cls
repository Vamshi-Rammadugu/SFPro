public with sharing class ClaudeService {

    private static final String NAMED_CREDENTIAL = 'callout:Anthropic_API';
    private static final String MODEL = 'claude-opus-4-7';
    private static final Integer MAX_TOKENS = 1024;

    public class ClaudeMessage {
        public String role;
        public String content;
        public ClaudeMessage(String role, String content) {
            this.role = role;
            this.content = content;
        }
    }

    public static String chat(List<ClaudeMessage> messages, String systemPrompt) {
        Map<String, Object> payload = new Map<String, Object>{
            'model' => MODEL,
            'max_tokens' => MAX_TOKENS,
            'system' => systemPrompt,
            'messages' => messages
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/v1/messages');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('anthropic-version', '2023-06-01');
        req.setTimeout(30000);
        req.setBody(JSON.serialize(payload));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new AuraHandledException('Claude API error ' + res.getStatusCode() + ': ' + res.getBody());
        }

        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> content = (List<Object>) body.get('content');
        Map<String, Object> firstBlock = (Map<String, Object>) content[0];
        return (String) firstBlock.get('text');
    }
}