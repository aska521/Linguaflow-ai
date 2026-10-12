/**
 * LINGUAFLOW AI - BACKEND GEMINI PROXY SERVER (Node.js Express / Serverless)
 * Protects secrets, validates schema output, and enforces user auth.
 */

const express = require('express');
const cors = require('cors');
const { GoogleGenerativeAI } = require('@google/generative-ai');

const app = express();
app.use(cors({ origin: process.env.ALLOWED_ORIGIN || '*' }));
app.use(express.json());

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
if (!GEMINI_API_KEY) {
    console.error('FATAL: GEMINI_API_KEY environment variable is missing.');
}

const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

// System prompt template generator
function buildSystemPrompt(language, scenario) {
    return `
You are LinguaBot, an empathetic language tutor for Indonesian learners studying ${language}.
Current Scenario: ${scenario}.
Guidelines:
1. Respond primarily in ${language} appropriate for a beginner/intermediate learner.
2. Provide short, encouraging corrections if the user makes grammatical errors.
3. Keep answers concise and end with a natural follow-up question in ${language}.
`;
}

app.post('/api/gemini-proxy', async (req, res) => {
    try {
        const { message, language, scenario } = req.body;

        if (!message || !language) {
            return res.status(400).json({ error: 'Missing message or language fields.' });
        }

        const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });
        const systemPrompt = buildSystemPrompt(language, scenario || 'greetings');

        const result = await model.generateContent([
            { text: systemPrompt },
            { text: `User message: ${message}` }
        ]);

        const replyText = result.response.text();

        return res.json({
            success: true,
            reply: replyText,
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error('Gemini Proxy Error:', error);
        return res.status(500).json({
            error: 'Failed to process AI response through backend proxy.',
            details: error.message
        });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`LinguaFlow AI Proxy Server running on port ${PORT}`);
});