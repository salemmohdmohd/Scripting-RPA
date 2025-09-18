/**
 * Google Apps Script for Company Learning Curriculum Design
 * - Uses Google Form and Sheet
 * - Analyzes responses and suggests a learning path (digital upskilling, management, knowledge, etc.)
 * - Emails sales manager with summary and recommendations
 */

// Recommended Google Form fields:
// - Company Name
// - Contact Email
// - Department/Team
// - Main Learning Goal (short answer)
// - Areas to Upskill (Checkbox: Digital Tools, Management, Industry Knowledge, Communication, Data Skills, Other)
// - Preferred Learning Format (Dropdown: Online, In-person, Hybrid)
// - Number of Employees
// - Timeline for Implementation
// - Additional Comments

/**
 * Triggered on form submission. Suggests learning path and emails sales manager.
 */
function onFormSubmit(e) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  var headers = sheet.getDataRange().getValues()[0];
  var companyCol = headers.indexOf('Company Name');
  var emailCol = headers.indexOf('Contact Email');
  var goalCol = headers.indexOf('Main Learning Goal');
  var upskillCol = headers.indexOf('Areas to Upskill');
  var formatCol = headers.indexOf('Preferred Learning Format');
  var numCol = headers.indexOf('Number of Employees');
  var timelineCol = headers.indexOf('Timeline for Implementation');
  if (companyCol === -1 || emailCol === -1 || goalCol === -1 || upskillCol === -1 || formatCol === -1 || numCol === -1 || timelineCol === -1) throw 'Required column not found.';

  var lastRow = sheet.getLastRow();
  var rowData = sheet.getRange(lastRow, 1, 1, sheet.getLastColumn()).getValues()[0];
  var companyName = rowData[companyCol];
  var contactEmail = rowData[emailCol];
  var mainGoal = rowData[goalCol];
  var upskillAreas = rowData[upskillCol];
  var format = rowData[formatCol];
  var numEmployees = rowData[numCol];
  var timeline = rowData[timelineCol];

  // Recommend learning path
  var learningPath = recommendLearningPath(upskillAreas, mainGoal);

  var summary = 'Company: ' + companyName + '\nContact: ' + contactEmail + '\nGoal: ' + mainGoal + '\nUpskill Areas: ' + upskillAreas + '\nFormat: ' + format + '\nEmployees: ' + numEmployees + '\nTimeline: ' + timeline + '\n\nRecommended Learning Path: ' + learningPath;

  // Email sales manager
  var salesManagerEmail = 'salesmanager@yourcompany.com'; // <-- Replace with your sales manager's email
  MailApp.sendEmail({
    to: salesManagerEmail,
    subject: 'New Learning Curriculum Request: ' + companyName,
    body: summary
  });
}

function recommendLearningPath(upskillAreas, mainGoal) {
  var path = '';
  if (upskillAreas.indexOf('Digital Tools') !== -1) {
    path += 'Digital Upskilling (Google Workspace, automation, data analysis).\n';
  }
  if (upskillAreas.indexOf('Management') !== -1) {
    path += 'Management Training (leadership, project management, change management).\n';
  }
  if (upskillAreas.indexOf('Industry Knowledge') !== -1) {
    path += 'Industry Knowledge (market trends, compliance, best practices).\n';
  }
  if (upskillAreas.indexOf('Communication') !== -1) {
    path += 'Communication Skills (presentations, collaboration, negotiation).\n';
  }
  if (upskillAreas.indexOf('Data Skills') !== -1) {
    path += 'Data Skills (analytics, visualization, reporting).\n';
  }
  if (!path) {
    path = 'Custom learning path based on your main goal: ' + mainGoal;
  }
  return path;
}

/**
 * Setup instructions:
 * 1. Create a Google Form with the above fields and link to a Sheet.
 * 2. In the Sheet, go to Extensions > Apps Script, paste this code.
 * 3. Set a trigger: Edit > Current project's triggers > Add Trigger > onFormSubmit > From spreadsheet > On form submit.
 * 4. Each submission will be analyzed and sent to the sales manager for curriculum crafting.
 */
