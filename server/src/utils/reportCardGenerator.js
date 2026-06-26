const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

/**
 * Generates a PDF report card for a student
 * @param {Object} data - Contains student, exam, and results data
 * @returns {Promise<Buffer>} - PDF buffer
 */
const generateReportCardPDF = async (data) => {
    return new Promise((resolve, reject) => {
        try {
            const doc = new PDFDocument({ margin: 50, size: 'A4' });
            let buffers = [];
            doc.on('data', buffers.push.bind(buffers));
            doc.on('end', () => resolve(Buffer.concat(buffers)));

            const { student, exam, results, term, class: className, section, academicYear, template, schoolConfig } = data;

            // School branding
            const schoolName = schoolConfig?.schoolName || process.env.SCHOOL_NAME || '';
            const logoPath = schoolConfig?.logoPath || null;

            // Template Settings
            const showAttendance = template?.showAttendance ?? true;
            const showRemarks = template?.showRemarks ?? true;
            const showRank = template?.showRank ?? false;
            const signedByTeacher = template?.signedByTeacher ?? true;
            const signedByPrincipal = template?.signedByPrincipal ?? true;

            // Header — use logo if available, otherwise text
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
                doc.fillColor('#444444')
                    .fontSize(20)
                    .text(schoolName, 110, 50);
            }

            doc.fontSize(10)
                .text('Progress Report Card', 110, 80)
                .text(`Academic Year: ${academicYear}`, 110, 95)
                .moveDown();

            // Horizontal Line
            doc.moveTo(50, 120).lineTo(550, 120).stroke();

            // Student Information
            doc.fontSize(12).fillColor('#000000');
            const studentInfoY = 140;
            doc.text(`Student Name: ${student.name}`, 50, studentInfoY);
            doc.text(`Admission No: ${student.admissionNo}`, 350, studentInfoY);
            doc.text(`Class: ${className}`, 50, studentInfoY + 20);
            doc.text(`Section: ${section}`, 350, studentInfoY + 20);
            doc.text(`Exam: ${exam.name}`, 50, studentInfoY + 40);
            doc.text(`Term: ${term}`, 350, studentInfoY + 40);

            // Marks Table Header
            const tableTop = 220;
            doc.fontSize(10).fillColor('#444444');
            const columns = [
                { label: 'Subject', x: 50, width: 150 },
                { label: 'Theory', x: 200, width: 60 },
                { label: 'Practical', x: 260, width: 60 },
                { label: 'Internal', x: 320, width: 60 },
                { label: 'Total', x: 380, width: 60 },
                { label: 'Grade', x: 440, width: 60 },
                { label: 'Result', x: 500, width: 50 }
            ];

            // Draw Table Header Background
            doc.rect(50, tableTop, 505, 20).fill('#EEEEEE');
            doc.fillColor('#000000').fontSize(10);
            columns.forEach(col => {
                doc.text(col.label, col.x, tableTop + 5);
            });

            // Table Rows
            let currentY = tableTop + 25;
            results.forEach((res, index) => {
                // Alternating row background
                if (index % 2 === 1) {
                    doc.rect(50, currentY - 2, 505, 18).fill('#F9F9F9');
                }
                doc.fillColor('#000000');

                doc.text(res.subjectName, 50, currentY);

                if (res.isAbsent) {
                    doc.fillColor('#E53935').text(res.absenceType || 'ABSENT', 200, currentY, { width: 180, align: 'center' });
                    doc.fillColor('#000000');
                } else {
                    doc.text((res.theoryObtained ?? '-').toString(), 200, currentY, { width: 60, align: 'center' });
                    doc.text((res.practicalObtained ?? '-').toString(), 260, currentY, { width: 60, align: 'center' });
                    doc.text((res.internalObtained ?? '-').toString(), 320, currentY, { width: 60, align: 'center' });
                    doc.text((res.obtainedMarks ?? 0).toString(), 380, currentY, { width: 60, align: 'center' });
                }

                doc.text(res.grade || '-', 440, currentY, { width: 60, align: 'center' });

                const resultText = res.isAbsent ? 'AB' : ((res.obtainedMarks ?? 0) >= (res.passMarks || 33) ? 'PASS' : 'FAIL');
                doc.fillColor(resultText === 'PASS' ? '#2E7D32' : '#C62828').text(resultText, 500, currentY);
                doc.fillColor('#000000');

                currentY += 20;
            });

            // Summary section
            const summaryY = currentY + 30;
            const totalObtained = results.reduce((sum, r) => sum + (r.obtainedMarks || 0), 0);
            const totalMax = results.reduce((sum, r) => sum + (r.totalMarks || 100), 0);
            const percentage = ((totalObtained / totalMax) * 100).toFixed(2);

            doc.rect(50, summaryY, 505, 80).stroke();
            doc.fontSize(11).font('Helvetica-Bold');
            doc.text(`Grand Total: ${totalObtained} / ${totalMax}`, 60, summaryY + 15);
            doc.text(`Percentage: ${percentage}%`, 60, summaryY + 35);
            doc.text(`Result Status: ${percentage >= 33 ? 'PASS (QUALIFIED)' : 'FAIL (NOT QUALIFIED)'}`, 60, summaryY + 55);

            if (showRank) {
                doc.text(`Class Rank: --`, 350, summaryY + 15); // Rank logic can be added later
            }

            if (showAttendance) {
                doc.fontSize(10).font('Helvetica');
                doc.text(`Attendance: ${data.attendance || '--'}%`, 350, summaryY + 35);
            }

            if (showRemarks) {
                doc.text(`Class Teacher Remarks: ${data.remarks || '--'}`, 60, summaryY + 95, { width: 480 });
            }

            // Footer
            const footerY = 750;
            doc.moveTo(50, footerY).lineTo(550, footerY).stroke();
            doc.fontSize(10).font('Helvetica');

            if (signedByTeacher) {
                doc.text('Class Teacher Signature', 50, footerY + 15);
            }
            if (signedByPrincipal) {
                doc.text('Principal Signature', 450, footerY + 15);
            }

            doc.text(`Generated on ${new Date().toLocaleDateString()}`, 50, footerY + 40, { align: 'center', width: 500 });

            doc.end();
        } catch (error) {
            reject(error);
        }
    });
};

module.exports = { generateReportCardPDF };
