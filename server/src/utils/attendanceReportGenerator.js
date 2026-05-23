const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

/**
 * Generates a PDF attendance report for a student
 * @param {Object} data - Contains student, attendance records, stats and subject-wise data
 * @returns {Promise<Buffer>} - PDF buffer
 */
const generateAttendanceReportPDF = async (data) => {
    return new Promise((resolve, reject) => {
        try {
            const doc = new PDFDocument({ margin: 50, size: 'A4' });
            let buffers = [];
            doc.on('data', buffers.push.bind(buffers));
            doc.on('end', () => resolve(Buffer.concat(buffers)));

            const { student, attendance, stats, subjectWise, schoolConfig, dateRange } = data;

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
                    // Skip logo if error
                }
                doc.fontSize(18).fillColor('#2563EB').text(schoolName, 110, 50);
            } else {
                doc.fillColor('#2563EB').fontSize(20).text(schoolName, 50, 50);
            }

            doc.fontSize(10).fillColor('#444444')
                .text('Attendance Performance Report', 50, 85, { align: 'right' })
                .text(`Period: ${dateRange.start} to ${dateRange.end}`, 50, 100, { align: 'right' })
                .moveDown();

            // Horizontal Line
            doc.moveTo(50, 120).lineTo(545, 120).stroke('#EEEEEE');

            // Student Information
            doc.fontSize(12).fillColor('#000000').font('Helvetica-Bold');
            doc.text('Student Profile', 50, 140);
            
            doc.font('Helvetica').fontSize(10);
            doc.text(`Name: ${student.name}`, 50, 160);
            doc.text(`Admission Number: ${student.admissionNo}`, 50, 175);
            doc.text(`Class: ${student.className || 'N/A'}`, 300, 160);
            doc.text(`Section: ${student.sectionName || 'N/A'}`, 300, 175);

            // Statistics Summary
            const statsY = 210;
            doc.rect(50, statsY, 115, 60).fill('#ECFDF5'); // Present
            doc.rect(175, statsY, 115, 60).fill('#FEF2F2'); // Absent
            doc.rect(300, statsY, 115, 60).fill('#FFFBEB'); // Late
            doc.rect(425, statsY, 120, 60).fill('#EFF6FF'); // Percentage

            doc.fillColor('#065F46').fontSize(8).font('Helvetica-Bold');
            doc.text('PRESENT', 60, statsY + 15);
            doc.fillColor('#991B1B').text('ABSENT', 185, statsY + 15);
            doc.fillColor('#92400E').text('LATE', 310, statsY + 15);
            doc.fillColor('#1E40AF').text('TOTAL ATTENDANCE', 435, statsY + 15);

            doc.fontSize(14).font('Helvetica-Bold');
            doc.fillColor('#065F46').text(`${stats.present}`, 60, statsY + 35);
            doc.fillColor('#991B1B').text(`${stats.absent}`, 185, statsY + 35);
            doc.fillColor('#92400E').text(`${stats.late}`, 310, statsY + 35);
            doc.fillColor('#1E40AF').text(`${stats.percentage}%`, 435, statsY + 35);

            // Subject-wise Table
            doc.fillColor('#000000').fontSize(12).font('Helvetica-Bold');
            doc.text('Subject-wise Analysis', 50, 290);
            
            const tableTop = 315;
            doc.rect(50, tableTop, 495, 20).fill('#F9FAFB');
            doc.fillColor('#374151').fontSize(9).font('Helvetica-Bold');
            doc.text('SUBJECT', 60, tableTop + 7);
            doc.text('TOTAL', 250, tableTop + 7, { width: 50, align: 'center' });
            doc.text('PRESENT', 310, tableTop + 7, { width: 50, align: 'center' });
            doc.text('ABSENT', 370, tableTop + 7, { width: 50, align: 'center' });
            doc.text('SCORE', 430, tableTop + 7, { width: 100, align: 'right' });

            let currentY = tableTop + 25;
            doc.font('Helvetica').fontSize(9).fillColor('#111827');

            subjectWise.forEach((sub, index) => {
                if (index % 2 === 1) doc.rect(50, currentY - 3, 495, 20).fill('#FDFDFD');
                
                doc.text(sub.name, 60, currentY, { width: 180, truncate: true });
                doc.text(`${sub.total}`, 250, currentY, { width: 50, align: 'center' });
                doc.text(`${sub.present}`, 310, currentY, { width: 50, align: 'center' });
                doc.text(`${sub.absent}`, 370, currentY, { width: 50, align: 'center' });
                
                const pct = parseFloat(sub.percentage);
                const color = pct >= 75 ? '#059669' : '#DC2626';
                doc.fillColor(color).text(`${sub.percentage}%`, 430, currentY, { width: 100, align: 'right' });
                doc.fillColor('#111827');

                currentY += 20;
            });

            // Attendance Log Snippet (Last 15 records)
            doc.moveDown(2);
            currentY += 20;
            if (currentY > 750) {
                doc.addPage();
                currentY = 50;
            }

            doc.fillColor('#000000').fontSize(12).font('Helvetica-Bold').text('Recent Daily Logs', 50, currentY);
            currentY += 20;
            
            doc.rect(50, currentY, 495, 18).fill('#F3F4F6');
            doc.fillColor('#4B5563').fontSize(8).text('DATE', 60, currentY + 5);
            doc.text('STATUS', 200, currentY + 5);
            doc.text('TIME', 300, currentY + 5);
            doc.text('MARKED BY', 400, currentY + 5);
            currentY += 23;

            attendance.slice(0, 15).forEach(rec => {
                doc.fillColor('#111827').fontSize(8);
                doc.text(new Date(rec.date).toLocaleDateString(), 60, currentY);
                doc.text(rec.status, 200, currentY);
                doc.text(rec.checkInTime ? new Date(rec.checkInTime).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '-', 300, currentY);
                doc.text(rec.markedByName || 'System', 400, currentY);
                currentY += 15;
            });

            // Footer
            doc.fontSize(8).fillColor('#9CA3AF').text('This is an automated attendance summary report.', 50, 780, { align: 'center', width: 500 });

            doc.end();
        } catch (error) {
            reject(error);
        }
    });
};

module.exports = { generateAttendanceReportPDF };
