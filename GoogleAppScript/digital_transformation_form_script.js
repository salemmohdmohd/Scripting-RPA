/**
 * Google Apps Script for Digital Transformation Client Form
 * - Uses Google Form and Sheet
 * - On submission, emails client with recommended change management style and transformation area
 */

// Digital Transformation Areas:
// - Process Transformation
// - Business Model Transformation
// - Domain Transformation
// - Cultural/Organizational Transformation

// Change Management Styles:
// - Kotter’s 8-Step Change Model
// - ADKAR Model
// - Lewin’s Change Management Model
// - McKinsey 7-S Framework

/**
 * Triggered on form submission. Sends recommendations to client.
 */
function onFormSubmit(e) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  var headers = sheet.getDataRange().getValues()[0];
  var emailCol = headers.indexOf('Contact Email');
  var companyCol = headers.indexOf('Company Name');
  var areaCol = headers.indexOf('What area do you want to transform?');
  var paceCol = headers.indexOf('Preferred pace of change');
  if (emailCol === -1 || companyCol === -1 || areaCol === -1 || paceCol === -1) throw 'Required column not found.';

  var lastRow = sheet.getLastRow();
  var rowData = sheet.getRange(lastRow, 1, 1, sheet.getLastColumn()).getValues()[0];
  var clientEmail = rowData[emailCol];
  var companyName = rowData[companyCol];
  var area = rowData[areaCol];
  var pace = rowData[paceCol];

  // Recommend change management style based on pace
  var changeStyle = recommendChangeManagementStyle(pace);
  var areaDesc = recommendTransformationArea(area);

  var subject = 'Digital Transformation Recommendations for ' + companyName;
  var body = 'Dear ' + companyName + ',\n\nThank you for your submission.\n\nBased on your needs, we recommend:\n\nDigital Transformation Area: ' + areaDesc + '\nChange Management Style: ' + changeStyle + '\n\nWe look forward to supporting your transformation journey!\n\nBest regards,\nDigital Transformation Team';

  MailApp.sendEmail({
    to: clientEmail,
    subject: subject,
    body: body
  });
}

function recommendChangeManagementStyle(pace) {
  switch (pace) {
    case 'Rapid':
      return "Kotter’s 8-Step Change Model";
    case 'Gradual':
      return "ADKAR Model";
    case 'Pilot':
      return "Lewin’s Change Management Model";
    case 'Full-scale':
      return "McKinsey 7-S Framework";
    default:
      return "ADKAR Model";
  }
}

function recommendTransformationArea(area) {
  switch (area) {
    case 'Process':
      return "Process Transformation (optimizing workflows and automation)";
    case 'Business Model':
      return "Business Model Transformation (new revenue streams, digital products)";
    case 'Domain':
      return "Domain Transformation (expanding into new markets or industries)";
    case 'Culture':
      return "Cultural/Organizational Transformation (change in mindset, leadership, collaboration)";
    default:
      return area;
  }
}

/**
 * Setup instructions:
 * 1. Create a Google Form with the above fields and link to a Sheet.
 * 2. In the Sheet, go to Extensions > Apps Script, paste this code.
 * 3. Set a trigger: Edit > Current project's triggers > Add Trigger > onFormSubmit > From spreadsheet > On form submit.
 * 4. Each client submission will receive an automatic recommendation email.
 */
