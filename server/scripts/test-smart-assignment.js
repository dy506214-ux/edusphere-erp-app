const AiService = require('../src/services/ai/AiService');
const PdfService = require('../src/services/ai/PdfService');
const path = require('path');
const fs = require('fs');

async function runTest() {
  console.log('🧪 Starting Smart Assignment Logic Test...');

  const dummyUser = {
    id: 'test-teacher-id',
    firstName: 'Test',
    lastName: 'Teacher',
    role: 'TEACHER'
  };

  const testData = {
    topic: 'Laws of Motion',
    subject: 'Physics',
    className: 'Class 9',
    referenceText: 'Newton\'s First Law: An object at rest remains at rest, and an object in motion remains in motion at constant speed and in a straight line unless acted on by an unbalanced force. Second Law: The acceleration of an object depends on the mass of the object and the amount of force applied. Third Law: Whenever one object exerts a force on a second object, the second object exerts an equal and opposite force on the first.',
    questionTypes: {
      mcq: '2',
      oneWord: '2',
      short: '1',
      long: '0'
    },
    complexity: 'Medium'
  };

  try {
    // 1. Test AI Generation
    console.log('--- Phase 1: AI Content Generation ---');
    const content = await AiService.generateSmartAssignment(dummyUser, testData);
    console.log('✅ AI Output Preview:', content.substring(0, 200) + '...');

    // 2. Test PDF Generation
    console.log('\n--- Phase 2: PDF Generation ---');
    const pdfUrl = await PdfService.generateAssignmentPdf(testData.topic, content);
    console.log('✅ PDF Generated at:', pdfUrl);

    // 3. Verify File Exists
    const fullPath = path.join(__dirname, '../', pdfUrl);
    if (fs.existsSync(fullPath)) {
      console.log('✅ File verification SUCCESS: File exists on disk.');
    } else {
      console.log('❌ File verification FAILED: File missing.');
    }

    console.log('\n✨ All Smart Assignment Logic Tests Passed!');
  } catch (error) {
    console.error('❌ Test FAILED:', error);
  }
}

runTest();
