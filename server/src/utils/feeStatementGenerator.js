const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

/**
 * Generates a PDF fee statement for a student
 * @param {Object} data - Contains student, ledgers, and summary data
 * @returns {Promise<Buffer>} - PDF buffer
 */
const generateFeeStatementPDF = async (data) => {
    return new Promise((resolve, reject) => {
        try {
            const doc = new PDFDocument({ margin: 50, size: 'A4' });
            let buffers = [];
            doc.on('data', buffers.push.bind(buffers));
            doc.on('end', () => resolve(Buffer.concat(buffers)));

            const { student, ledgers, summary, schoolConfig } = data;

            // Simple currency formatter if not imported
            const format = (amt) => `INR ${parseFloat(amt).toLocaleString('en-IN', { minimumFractionDigits: 2 })}`;

            // School branding
            const schoolName = schoolConfig?.schoolName || process.env.SCHOOL_NAME || 'EduSphere ERP';
            const logoPath = schoolConfig?.logoPath || null;

            // Header
            if (logoPath) {
                try {
                    const absoluteLogoPath = path.join(__dirname, '../..', logoPath);
                    if (fs.existsSync(absoluteLogoPath)) {
                        doc.image(absoluteLogoPath, 50, 35, { width: 50, height: 50 });
                    }
                } catch (e) {
                    // Skip logo if file is invalid
                }
                doc.fontSize(20).fillColor('#2563EB').text(schoolName, 110, 50);
            } else {
                doc.fillColor('#2563EB')
                    .fontSize(22)
                    .text(schoolName, 50, 50);
            }

            doc.fontSize(10).fillColor('#444444')
                .text('Official Fee Statement', 50, 85, { align: 'right' })
                .text(`Generated on: ${new Date().toLocaleDateString()}`, 50, 100, { align: 'right' })
                .moveDown();

            // Horizontal Line
            doc.moveTo(50, 120).lineTo(545, 120).stroke('#EEEEEE');

            // Student Information
            doc.fontSize(12).fillColor('#000000').font('Helvetica-Bold');
            doc.text('Student Details', 50, 140);
            
            doc.font('Helvetica').fontSize(10);
            doc.text(`Name: ${student.name}`, 50, 160);
            doc.text(`Admission No: ${student.admissionNo}`, 50, 175);
            doc.text(`Class: ${student.class || 'N/A'}`, 300, 160);
            doc.text(`Section: ${student.section || 'N/A'}`, 300, 175);

            // Summary Cards (Rectangles)
            const summaryY = 210;
            doc.rect(50, summaryY, 155, 60).fill('#F3F4F6');
            doc.rect(215, summaryY, 155, 60).fill('#ECFDF5');
            doc.rect(380, summaryY, 165, 60).fill('#FEF2F2');

            doc.fillColor('#4B5563').fontSize(8);
            doc.text('TOTAL PAYABLE', 60, summaryY + 15);
            doc.text('TOTAL PAID', 225, summaryY + 15);
            doc.text('OUTSTANDING DUE', 390, summaryY + 15);

            doc.fillColor('#111827').fontSize(12).font('Helvetica-Bold');
            doc.text(format(summary.totalFees), 60, summaryY + 35);
            doc.fillColor('#059669').text(format(summary.totalPaid), 225, summaryY + 35);
            doc.fillColor('#DC2626').text(format(summary.totalDue), 390, summaryY + 35);

            // Table Header
            const tableTop = 300;
            doc.fillColor('#374151').font('Helvetica-Bold').fontSize(10);
            doc.rect(50, tableTop, 495, 25).fill('#F9FAFB');
            
            doc.fillColor('#374151');
            doc.text('FEE STRUCTURE', 60, tableTop + 8);
            doc.text('TOTAL', 280, tableTop + 8, { width: 80, align: 'right' });
            doc.text('PAID', 370, tableTop + 8, { width: 80, align: 'right' });
            doc.text('STATUS', 460, tableTop + 8, { width: 80, align: 'center' });

            // Table Rows
            let currentY = tableTop + 35;
            doc.font('Helvetica').fontSize(9);

            ledgers.forEach((ledger, index) => {
                if (index % 2 === 1) {
                    doc.rect(50, currentY - 5, 495, 25).fill('#FCFDFF');
                }
                
                doc.fillColor('#111827');
                doc.text(ledger.feeStructure?.name || 'Academic Fee', 60, currentY);
                doc.text(format(ledger.totalPayable), 280, currentY, { width: 80, align: 'right' });
                doc.text(format(ledger.totalPaid), 370, currentY, { width: 80, align: 'right' });
                
                // Status Badge logic
                const status = ledger.status || 'PENDING';
                const statusColor = status === 'PAID' ? '#059669' : (status === 'PARTIALLY_PAID' ? '#D97706' : '#DC2626');
                doc.fillColor(statusColor).text(status, 460, currentY, { width: 80, align: 'center' });

                currentY += 25;

                // Add new page if needed
                if (currentY > 700) {
                    doc.addPage();
                    currentY = 50;
                }
            });

            // Footer Note
            doc.fontSize(8).fillColor('#9CA3AF')
                .text('This is a computer generated document and does not require a physical signature.', 50, 780, { align: 'center', width: 500 });

            doc.end();
        } catch (error) {
            reject(error);
        }
    });
};

module.exports = { generateFeeStatementPDF };
