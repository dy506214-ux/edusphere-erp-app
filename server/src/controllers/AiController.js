const AiService = require('../services/ai/AiService');
const asyncHandler = require('express-async-handler');
const prisma = require('../config/database');

/**
 * AiController handles HTTP requests for the AI Assistant
 */

const AiController = {
  /**
   * Initializes the AI session and returns an initial greeting
   * POST /api/ai/init
   */
  initChat: asyncHandler(async (req, res) => {
    // Only Students and Teachers can use the AI
    if (!['STUDENT', 'TEACHER'].includes(req.user.role)) {
      return res.status(403).json({ success: false, error: 'AI Assistant is only available for Students and Teachers.' });
    }

    const greeting = await AiService.generateGreeting(req.user);
    res.json({
      success: true,
      greeting,
      user: {
        firstName: req.user.firstName,
        role: req.user.role
      }
    });
  }),

  /**
   * Handles user messages and returns AI responses
   * POST /api/ai/chat
   */
  sendMessage: asyncHandler(async (req, res) => {
    // Only Students and Teachers can use the AI
    if (!['STUDENT', 'TEACHER'].includes(req.user.role)) {
      return res.status(403).json({ success: false, error: 'AI Assistant is only available for Students and Teachers.' });
    }

    const { message, history } = req.body;

    if (!message) {
      return res.status(400).json({ success: false, error: 'Message is required' });
    }

    const response = await AiService.generateResponse(req.user, message, history || []);

    res.json({
      success: true,
      response
    });
  }),

  /**
   * POST /api/ai/action
   * Executes a confirmed AI draft
   */
  executeAction: asyncHandler(async (req, res) => {
    const { action, data } = req.body;
    const userId = req.user.userId || req.user.id;

    if (!['STUDENT', 'TEACHER'].includes(req.user.role)) {
      return res.status(403).json({ success: false, error: 'Unauthorized' });
    }

    let result;
    if (action === 'createAssignmentDraft') {
      const teacher = await prisma.teacher.findFirst({ where: { userId } });
      result = await prisma.assignment.create({
        data: {
          title: data.title,
          description: data.description,
          dueDate: new Date(data.dueDate),
          classId: data.classId,
          subjectId: data.subjectId,
          teacherId: teacher.id
        }
      });
    } else if (action === 'createNoteDraft') {
      result = await prisma.announcement.create({
        data: {
          title: data.title,
          content: data.content,
          priority: 'NORMAL',
          targetAudience: ['STUDENT'],
          // Targeting the specific class if possible
          // Announcement model might need a relation or category tweak
        }
      });
    }

    res.json({ success: true, message: 'Action executed successfully', result });
  }),

  /**
   * Generates a smart assignment content and a reference PDF
   * POST /api/ai/generate-smart-assignment
   */
  generateSmartAssignment: asyncHandler(async (req, res) => {
    if (req.user.role !== 'TEACHER') {
      return res.status(403).json({ success: false, error: 'Only teachers can generate smart assignments.' });
    }

    const { topic, subject, className, referenceText, questionTypes, complexity } = req.body;

    if (!topic || !referenceText) {
      return res.status(400).json({ success: false, error: 'Topic and Reference Source are required.' });
    }

    // 1. Generate AI Content
    const generatedContent = await AiService.generateSmartAssignment(req.user, {
      topic,
      subject,
      className,
      referenceText,
      questionTypes,
      complexity
    });

    // 2. Generate PDF Reference
    // Import here to avoid circular dependency if any
    const PdfService = require('../services/ai/PdfService');
    const pdfUrl = await PdfService.generateAssignmentPdf(topic, generatedContent);

    res.json({
      success: true,
      data: {
        description: `### Assignment: ${topic}\n\nGenerated using EduSphere AI.\n\n${generatedContent.substring(0, 500)}...`,
        fullContent: generatedContent,
        pdfUrl: pdfUrl
      }
    });
  })
};

module.exports = AiController;
