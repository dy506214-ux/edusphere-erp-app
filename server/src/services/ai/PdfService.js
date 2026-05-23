const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

class PdfService {
  constructor() {
    this.uploadDir = path.join(__dirname, '../../../uploads/assignments/references');
    // Ensure directory exists
    if (!fs.existsSync(this.uploadDir)) {
      fs.mkdirSync(this.uploadDir, { recursive: true });
    }
  }

  /**
   * Generates a PDF from markdown content
   * @param {string} title 
   * @param {string} content 
   * @returns {Promise<string>} relative path to the generated file
   */
  async generateAssignmentPdf(title, content) {
    return new Promise((resolve, reject) => {
      try {
        const fileName = `assignment_${uuidv4()}.pdf`;
        const filePath = path.join(this.uploadDir, fileName);
        const doc = new PDFDocument();

        const stream = fs.createWriteStream(filePath);
        doc.pipe(stream);

        // Add Header
        doc.fontSize(20).text('EduSphere ERP - Academic Assignment', { align: 'center' });
        doc.moveDown();
        doc.fontSize(16).text(title, { align: 'center', underline: true });
        doc.moveDown();

        // Add Date
        doc.fontSize(10).text(`Generated on: ${new Date().toLocaleDateString()}`, { align: 'right' });
        doc.moveDown();

        // Add Content (Simple markdown logic - headers and paragraphs)
        const lines = content.split('\n');
        lines.forEach(line => {
          if (line.startsWith('# ')) {
            doc.fontSize(14).fillColor('blue').text(line.replace('# ', ''), { underline: true });
          } else if (line.startsWith('## ')) {
            doc.fontSize(12).fillColor('black').text(line.replace('## ', ''), { bold: true });
          } else if (line.match(/^\d+\./) || line.startsWith('- ')) {
            doc.fontSize(11).fillColor('black').text(line, { indent: 10 });
          } else if (line.trim() !== '') {
            doc.fontSize(11).fillColor('black').text(line);
          }
          doc.moveDown(0.5);
        });

        doc.end();

        stream.on('finish', () => {
          // Return relative path for database and public access
          const relativePath = `/uploads/assignments/references/${fileName}`;
          resolve(relativePath);
        });

        stream.on('error', (err) => {
          reject(err);
        });
      } catch (error) {
        reject(error);
      }
    });
  }
}

module.exports = new PdfService();
