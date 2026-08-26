public with sharing class InterviewAgentController {

    // ── Topics ────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Interview_Topic__c> getTopics() {
        return [SELECT Id, Name, Category__c, Difficulty__c, Notes__c FROM Interview_Topic__c ORDER BY Category__c, Name];
    }

    @AuraEnabled
    public static Interview_Topic__c saveTopic(Interview_Topic__c topic) {
        upsert topic;
        return topic;
    }

    // ── Questions ─────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Interview_Question__c> getQuestions(Id topicId, String difficulty) {
        String q = 'SELECT Id, Name, Question_Text__c, Sample_Answer__c, Difficulty__c, Times_Asked__c, Avg_Score__c, Topic__c FROM Interview_Question__c';
        List<String> conds = new List<String>();
        if (topicId != null) conds.add('Topic__c = :topicId');
        if (String.isNotBlank(difficulty) && difficulty != 'All') conds.add('Difficulty__c = :difficulty');
        if (!conds.isEmpty()) q += ' WHERE ' + String.join(conds, ' AND ');
        q += ' ORDER BY Times_Asked__c ASC, Name ASC';
        return Database.query(q);
    }

    @AuraEnabled
    public static Interview_Question__c saveQuestion(Interview_Question__c question) {
        upsert question;
        return question;
    }

    @AuraEnabled
    public static void deleteQuestion(Id questionId) {
        delete new Interview_Question__c(Id = questionId);
    }

    // ── AI: Generate Questions ────────────────────────────────────────────────

    @AuraEnabled
    public static List<String> generateQuestions(String topicName, String category, String difficulty, Integer count) {
        String systemPrompt = 'You are an expert technical interviewer. Generate interview questions that are realistic, specific, and appropriately challenging.';
        String userPrompt = 'Generate exactly ' + count + ' ' + difficulty + '-level interview questions for the topic "' + topicName + '" in the ' + category + ' category.\n' +
            'Return ONLY a JSON array of question strings, no explanation. Example format:\n' +
            '["Question 1?", "Question 2?", "Question 3?"]';

        List<ClaudeService.ClaudeMessage> messages = new List<ClaudeService.ClaudeMessage>{
            new ClaudeService.ClaudeMessage('user', userPrompt)
        };

        String response = ClaudeService.chat(messages, systemPrompt);
        // extract JSON array from response
        Integer startIdx = response.indexOf('[');
        Integer endIdx = response.lastIndexOf(']');
        if (startIdx == -1 || endIdx == -1) return new List<String>{ response };
        return (List<String>) JSON.deserialize(response.substring(startIdx, endIdx + 1), List<String>.class);
    }

    // ── Sessions ──────────────────────────────────────────────────────────────

    @AuraEnabled
    public static Mock_Session__c startSession(Id topicId) {
        Mock_Session__c session = new Mock_Session__c(
            Topic__c = topicId,
            Session_Date__c = Datetime.now(),
            Status__c = 'In Progress',
            Questions_Asked__c = 0
        );
        insert session;
        return session;
    }

    @AuraEnabled(cacheable=true)
    public static List<Mock_Session__c> getRecentSessions(Integer lim) {
        return [
            SELECT Id, Name, Session_Date__c, Overall_Score__c, Questions_Asked__c, Status__c, AI_Summary__c, Topic__r.Name
            FROM Mock_Session__c
            ORDER BY Session_Date__c DESC
            LIMIT :lim
        ];
    }

    // ── AI: Evaluate Answer ───────────────────────────────────────────────────

    @AuraEnabled
    public static Map<String, Object> evaluateAnswer(Id sessionId, Id questionId, String questionText, String userAnswer, String sampleAnswer) {
        String systemPrompt = 'You are an expert technical interviewer giving constructive, honest feedback. ' +
            'Score answers 1-10 based on accuracy, completeness, clarity and depth. ' +
            'Be encouraging but honest about gaps. Keep feedback concise (3-5 sentences).';

        String userPrompt = 'Question: ' + questionText + '\n\n' +
            'Candidate Answer: ' + userAnswer + '\n\n' +
            (String.isNotBlank(sampleAnswer) ? 'Reference Answer: ' + sampleAnswer + '\n\n' : '') +
            'Respond with ONLY valid JSON in this exact format:\n' +
            '{"score": <number 1-10>, "feedback": "<your feedback>", "strengths": "<what was good>", "improvements": "<what to improve>"}';

        List<ClaudeService.ClaudeMessage> messages = new List<ClaudeService.ClaudeMessage>{
            new ClaudeService.ClaudeMessage('user', userPrompt)
        };

        String response = ClaudeService.chat(messages, systemPrompt);
        Integer startIdx = response.indexOf('{');
        Integer endIdx = response.lastIndexOf('}');
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(response.substring(startIdx, endIdx + 1));

        Integer score = Integer.valueOf(result.get('score'));
        String feedback = (String) result.get('feedback');
        String strengths = (String) result.get('strengths');
        String improvements = (String) result.get('improvements');
        String fullFeedback = '**Score: ' + score + '/10**\n\n' +
            feedback + '\n\n✅ Strengths: ' + strengths + '\n\n📈 Improve: ' + improvements;

        // Save response record
        Session_Response__c resp = new Session_Response__c(
            Session__c = sessionId,
            Question__c = questionId,
            Question_Text_Snapshot__c = questionText,
            User_Answer__c = userAnswer,
            AI_Feedback__c = fullFeedback,
            Score__c = score
        );
        insert resp;

        // Update session stats
        Mock_Session__c session = [SELECT Id, Questions_Asked__c, Overall_Score__c FROM Mock_Session__c WHERE Id = :sessionId];
        Decimal asked = (session.Questions_Asked__c == null ? 0 : session.Questions_Asked__c) + 1;
        Decimal prevTotal = ((session.Overall_Score__c == null ? 0 : session.Overall_Score__c) * (asked - 1));
        session.Questions_Asked__c = asked;
        session.Overall_Score__c = (prevTotal + score) / asked;
        update session;

        // Update question stats
        Interview_Question__c q = [SELECT Id, Times_Asked__c, Avg_Score__c FROM Interview_Question__c WHERE Id = :questionId];
        Decimal timesAsked = (q.Times_Asked__c == null ? 0 : q.Times_Asked__c) + 1;
        Decimal prevAvg = (q.Avg_Score__c == null ? 0 : q.Avg_Score__c) * (timesAsked - 1);
        q.Times_Asked__c = timesAsked;
        q.Avg_Score__c = (prevAvg + score) / timesAsked;
        update q;

        result.put('fullFeedback', fullFeedback);
        return result;
    }

    // ── AI: End Session Summary ───────────────────────────────────────────────

    @AuraEnabled
    public static String finishSession(Id sessionId) {
        Mock_Session__c session = [
            SELECT Id, Overall_Score__c, Questions_Asked__c,
                   (SELECT Question_Text_Snapshot__c, Score__c, AI_Feedback__c FROM Responses__r ORDER BY CreatedDate ASC)
            FROM Mock_Session__c WHERE Id = :sessionId
        ];

        String sessionData = 'Session had ' + session.Questions_Asked__c + ' questions. Overall score: ' + session.Overall_Score__c + '/10.\n\n';
        for (Session_Response__c r : session.Responses__r) {
            sessionData += 'Q: ' + r.Question_Text_Snapshot__c + '\nScore: ' + r.Score__c + '/10\n\n';
        }

        List<ClaudeService.ClaudeMessage> messages = new List<ClaudeService.ClaudeMessage>{
            new ClaudeService.ClaudeMessage('user', 'Based on this mock interview session, provide a 3-4 sentence coaching summary highlighting key strengths and the top 2-3 areas to focus on for improvement:\n\n' + sessionData)
        };

        String summary = ClaudeService.chat(messages, 'You are a supportive interview coach giving end-of-session feedback.');
        session.Status__c = 'Completed';
        session.AI_Summary__c = summary;
        update session;
        return summary;
    }

    // ── Progress ──────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getProgress() {
        List<Mock_Session__c> sessions = [
            SELECT Overall_Score__c, Session_Date__c, Questions_Asked__c
            FROM Mock_Session__c
            WHERE Status__c = 'Completed'
            ORDER BY Session_Date__c ASC
        ];

        List<Map<String, Object>> trend = new List<Map<String, Object>>();
        for (Mock_Session__c s : sessions) {
            trend.add(new Map<String, Object>{
                'date' => s.Session_Date__c.format('MMM d'),
                'score' => s.Overall_Score__c,
                'questions' => s.Questions_Asked__c
            });
        }

        Integer totalSessions = sessions.size();
        Decimal avgScore = 0;
        if (totalSessions > 0) {
            Decimal total = 0;
            for (Mock_Session__c s : sessions) total += (s.Overall_Score__c == null ? 0 : s.Overall_Score__c);
            avgScore = total / totalSessions;
        }

        return new Map<String, Object>{
            'totalSessions' => totalSessions,
            'avgScore' => avgScore.setScale(1),
            'trend' => trend,
            'totalQuestions' => [SELECT COUNT() FROM Session_Response__c]
        };
    }
}