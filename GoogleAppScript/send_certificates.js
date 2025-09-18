/**
 * Google Apps Script to send bulk certificate emails with PDF attachments from Google Sheets
 * Each row should contain: recipient email, sender email, date, course name, logo link, signature link, teacher name, student name, and other fields as needed.
 */

function onOpen() {
  var ui = SpreadsheetApp.getUi();
  ui.createMenu('Certificate Tools')
    .addItem('Send Certificates', 'sendBulkCertificates')
    .addToUi();
}

/**
 * Main function to send certificates in bulk
 * Reads each row and sends a personalized PDF certificate to the recipient
 */
function sendBulkCertificates() {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  var data = sheet.getDataRange().getValues();
  var headers = data[0];

  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    var rowData = {};
    for (var j = 0; j < headers.length; j++) {
      rowData[headers[j]] = row[j];
    }
    try {
      var pdfFile = generateCertificatePDF(rowData);
      sendCertificateEmail(rowData, pdfFile);
    } catch (e) {
      Logger.log('Error for row ' + (i+1) + ': ' + e);
    }
  }
  SpreadsheetApp.getUi().alert('Bulk certificate sending complete!');
}

/**
 * Generates a PDF certificate using a Google Doc template
 * @param {Object} rowData - Data for the certificate
 * @returns {GoogleAppsScript.Drive.File} PDF file
 */
function generateCertificatePDF(rowData) {
  // Create a new Google Doc from template
  var templateId = 'YOUR_TEMPLATE_DOC_ID'; // <-- Replace with your Google Doc template ID
  var docCopy = DriveApp.getFileById(templateId).makeCopy('Certificate for ' + rowData['Student Name']);
  var doc = DocumentApp.openById(docCopy.getId());
  var body = doc.getBody();

  // Replace placeholders in the template
  body.replaceText('{{STUDENT_NAME}}', rowData['Student Name']);
  body.replaceText('{{COURSE_NAME}}', rowData['Course Name']);
  body.replaceText('{{DATE}}', rowData['Date']);
  body.replaceText('{{TEACHER_NAME}}', rowData['Teacher Name']);
  // Add more replacements as needed

  // Insert logo and signature images
  if (rowData['Logo Link']) {
    var logoBlob = UrlFetchApp.fetch(rowData['Logo Link']).getBlob();
    body.insertImage(0, logoBlob);
  }
  if (rowData['Signature Link']) {
    var sigBlob = UrlFetchApp.fetch(rowData['Signature Link']).getBlob();
    body.appendImage(sigBlob);
  }

  doc.saveAndClose();

  // Export as PDF
  var pdf = DriveApp.getFileById(doc.getId()).getAs('application/pdf');
  docCopy.setTrashed(true); // Clean up temp doc
  return pdf;
}

/**
 * Sends the certificate PDF via email
 * @param {Object} rowData - Data for the certificate
 * @param {Blob} pdfFile - PDF file to attach
 */
function sendCertificateEmail(rowData, pdfFile) {
  var recipient = rowData['Recipient Email'];
  var sender = rowData['Sender Email'] || Session.getActiveUser().getEmail();
  var subject = 'Your Certificate for ' + rowData['Course Name'];
  var body = 'Dear ' + rowData['Student Name'] + ',\n\nCongratulations on completing ' + rowData['Course Name'] + '! Attached is your certificate.\n\nBest regards,\n' + rowData['Teacher Name'];

  MailApp.sendEmail({
    to: recipient,
    replyTo: sender,
    subject: subject,
    body: body,
    attachments: [pdfFile]
  });
}
