const { GoogleGenerativeAI } = require('@google/generative-ai');
const ContextFetchers = require('./ContextFetchers');
const logger = require('../../config/logger');

/**
 * AiService handles interactions with Google Gemini API
 * Expanded with Function Calling and Suggestion Engine
 */
class AiService {
  constructor() {
    this.genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    // Standardizing on gemini-1.5-flash for performance and stability
    this.modelName = "gemini-3-flash-preview";
    this.model = this.genAI.getGenerativeModel({ model: this.modelName });
  }

  /**
   * Generates a personalized academic greeting
   */
  async generateGreeting(user) {
    const role = user.role;
    const name = user.firstName;
    
    // Safety check: Only Students/Teachers allowed
    if (!['STUDENT', 'TEACHER'].includes(role)) {
      return "Hello! I am the EduSphere AI Academic Assistant.";
    }

    const prompt = `You are the EduSphere AI Academic Assistant. Greet ${name}, who is a ${role.toLowerCase()}. 
    Keep it warm, high-end, and under 20 words. Mention that you help with ${role === 'STUDENT' ? 'learning and schedules' : 'lesson planning and class management'}.`;

    try {
      const result = await this.model.generateContent(prompt);
      return result.response.text();
    } catch (error) {
      logger.error('Error generating AI greeting:', error);
      return `Hello ${user.firstName || 'there'}! Ready to tackle the academic day?`;
    }
  }

  /**
   * Generates a response with Native Function Calling and Proactive Suggestions
   */
  async generateResponse(user, message, history = []) {
    // 1. Role Authorization
    if (!['STUDENT', 'TEACHER'].includes(user.role)) {
      return "I'm sorry, I am currently configured to assist only Students and Teachers.";
    }

    // 2. Fetch Deep Context
    let context = {};
    try {
      if (user.role === 'STUDENT') {
        context = await ContextFetchers.getStudentContext(user.id);
      } else {
        context = await ContextFetchers.getTeacherContext(user.id);
      }
    } catch (error) {
      logger.error('Context Fetch Error:', error);
      context = "System Context: Error fetching real-time data.";
    }

    // 3. Define Tools (Function Calling) for Teachers
    const tools = [];
    if (user.role === 'TEACHER') {
      tools.push({
        functionDeclarations: [
          {
            name: "createAssignmentDraft",
            description: "DRAFTS an assignment for the teacher to review and create. Use when teacher wants to give work to students.",
            parameters: {
              type: "OBJECT",
              properties: {
                title: { type: "STRING", description: "Clear title for the assignment" },
                description: { type: "STRING", description: "Detailed instructions for students" },
                dueDate: { type: "STRING", description: "Due date in YYYY-MM-DD format" },
                classId: { type: "STRING", description: "The internal ID of the class" },
                subjectId: { type: "STRING", description: "The internal ID of the subject" }
              },
              required: ["title", "description", "dueDate", "classId", "subjectId"]
            }
          },
          {
            name: "createNoteDraft",
            description: "DRAFTS an academic note or announcement for students. Use for study material or quick updates.",
            parameters: {
              type: "OBJECT",
              properties: {
                title: { type: "STRING", description: "Title of the note" },
                content: { type: "STRING", description: "Full content of the note" },
                classId: { type: "STRING", description: "The internal ID of the targeted class" }
              },
              required: ["title", "content", "classId"]
            }
          }
        ]
      });
    }

    // 4. System Instruction
    const systemInstruction = `
      You are the official EduSphere AI "Academic Oracle", specialized for Students and Teachers.
      
      USER CONTEXT:
      - Name: ${user.firstName} ${user.lastName}
      - Role: ${user.role}
      - Data Snapshot: ${JSON.stringify(context)}
      
      BEHAVIOR RULES:
      1. Only use the "Data Snapshot" for answering questions about grades, schedules, fees, and class lists.
      2. If drafting an assignment/note, match the Subject ID and Class ID from the "assignedGroups" in the Snapshot.
      3. For Students: Access "reportCard" for grades, "dateSheet" for exam dates, and "feeStatus" for dues.
      4. For Teachers: Access "studentRoster" to give progress updates on specific students in your classes.
      5. For every response, append 2-3 tailored follow-up suggestions using the format: [SUGGESTION: Your Text Here].
      6. Use a premium, helpful, and concise tone. Format using Markdown.
      7. If the user is a teacher and wants to create something, use the tool CALLS to suggest a draft.
    `;

    try {
      const modelWithTools = this.genAI.getGenerativeModel({ 
        model: this.modelName,
        systemInstruction,
        tools
      });

      // Process history
      let validHistory = [];
      let foundFirstUser = false;
      for (const h of history) {
        if (h.role === 'user') foundFirstUser = true;
        if (foundFirstUser) {
          validHistory.push({
            role: h.role === 'user' ? 'user' : 'model',
            parts: [{ text: h.content }],
          });
        }
      }

      const chat = modelWithTools.startChat({ 
        history: validHistory,
        generationConfig: {
          maxOutputTokens: 2048,
          temperature: 0.7
        } 
      });
      
      logger.info(`AI Request for user ${user.id} (${user.role}) - History depth: ${validHistory.length}`);
      const result = await chat.sendMessage(message);
      
      // Handle tool calls or plain text
      const call = result.response.candidates[0].content.parts.find(p => p.functionCall);
      if (call) {
        // Return structured data for the frontend to render the "Draft Card"
        return `[ACTION:${call.functionCall.name}:${JSON.stringify(call.functionCall.args)}] I have drafted this ${call.functionCall.name === 'createAssignmentDraft' ? 'assignment' : 'note'} for you. Please review the details below to confirm creation.`;
      }

      return result.response.text();
    } catch (error) {
      logger.error('Gemini Engine Error:', error);
      return `I apologize, ${user.firstName || 'Teacher'}. I'm having trouble connecting to the school data right now. Please try again in a moment.`;
    }
  }

  /**
   * Generates a full assignment based on specific parameters and reference text
   */
  async generateSmartAssignment(user, data) {
    const { topic, subject, className, referenceText, questionTypes, complexity } = data;

    const prompt = `
      You are an expert ${subject} teacher for ${className}. 
      Generate a professional academic assignment about "${topic}".
      
      COMPLEXITY LEVEL: ${complexity}
      
      REFERENCE MATERIAL (Strictly follow this context): 
      ${referenceText}
      
      QUESTION REQUIREMENTS:
      ${questionTypes.mcq ? `- Generate ${questionTypes.mcq} Multiple Choice Questions (with options A-D).` : ''}
      ${questionTypes.oneWord ? `- Generate ${questionTypes.oneWord} One-Word/Fill-in-the-blank questions.` : ''}
      ${questionTypes.short ? `- Generate ${questionTypes.short} Short Answer questions.` : ''}
      ${questionTypes.long ? `- Generate ${questionTypes.long} Long/Descriptive Answer questions.` : ''}
      
      OUTPUT FORMAT:
      Return a Markdown structured assignment with:
      1. A professional Title.
      2. Clear Instructions.
      3. Section-wise questions (Section A: MCQs, Section B: Short Answers, etc.).
      4. A hidden Answer Key at the very end.
    `;

    try {
      const model = this.genAI.getGenerativeModel({ model: this.modelName });
      const result = await model.generateContent(prompt);
      return result.response.text();
    } catch (error) {
      logger.error('Smart Assignment Generation Error:', error);
      throw new Error('Failed to generate assignment content');
    }
  }
}

module.exports = new AiService();
