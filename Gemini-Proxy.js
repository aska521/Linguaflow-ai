/**
 * LINGUAFLOW AI - VERCEL SERVERLESS FUNCTION API PROXY
 * File Path: api/gemini-proxy.js
 */

const { GoogleGenerativeAI } = require('@google/generative-ai');

module.exports = async (req, res) => {
    // Enable CORS Headers
    res.setHeader('Access-Control-Allow-Credentials', true);
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
    res.setHeader(
        'Access-Control-Allow-Headers',
        'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version'
    );

    // Handle OPTIONS Preflight Request
    if (req.method === 'OPTIONS') {
        res.status(200).end();
        return;
    }

    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method Not Allowed' });
    }

    try {
        const { message, language, scenario } = req.body;

        if (!message || !language) {
            return res.status(400).json({ error: 'Parameter message dan language wajib diisi.' });
        }

        const apiKey = process.env.GEMINI_API_KEY;
        if (!apiKey) {
            return res.status(500).json({ error: 'GEMINI_API_KEY belum terpasang di Vercel Environment Variables.' });
        }

        const genAI = new GoogleGenerativeAI(apiKey);
        const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

        const systemPrompt = `
You are LinguaBot, an empathetic language tutor for Indonesian learners studying ${language}.
Current Scenario: ${scenario || 'greetings'}.
Guidelines:
1. Respond primarily in ${language} appropriate for a beginner/intermediate learner.
2. Provide short, encouraging corrections in Indonesian if the user makes grammatical errors.
3. Keep answers concise and end with a natural follow-up question in ${language}.
`;

        const result = await model.generateContent([
            { text: systemPrompt },
            { text: `User message: ${message}` }
        ]);

        const replyText = result.response.text();

        return res.status(200).json({
            success: true,
            reply: replyText,
            timestamp: new Date().toISOString()
        });

    } catch (error) {
        console.error('Vercel Gemini Proxy Error:', error);
        return res.status(500).json({
            error: 'Gagal memproses respons AI dari server proxy.',
            details: error.message
        });
    }
};