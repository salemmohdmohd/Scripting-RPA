/**
 * Google Apps Script for Freelance Database Management
 * - Collects freelancer info via Google Form
 * - Auto-sorts freelancers by type in the linked Sheet
 */

// Recommended Google Form fields:
// - Name
// - Email
// - Phone Number
// - Portfolio Link
// - Resume Link
// - Resume Upload (File upload)
// - Available Time
// - Country
// - Time Zone
// - Freelancer Type (Dropdown: Videographer, Developer, Animator, Graphic Designer, Instructor, Tech Instructor, Accounting Instructor, Machine Learning Instructor, Other)

/**
 * Triggered on form submission. Sorts freelancers by type into separate sheets.
 */
function onFormSubmit(e) {

  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  var headers = sheet.getDataRange().getValues()[0];
  var typeCol = headers.indexOf('Freelancer Type');
  var emailCol = headers.indexOf('Email');
  var nameCol = headers.indexOf('Name');
  if (typeCol === -1) throw 'Freelancer Type column not found.';
  if (emailCol === -1) throw 'Email column not found.';
  if (nameCol === -1) throw 'Name column not found.';

  var lastRow = sheet.getLastRow();
  var rowData = sheet.getRange(lastRow, 1, 1, sheet.getLastColumn()).getValues()[0];
  var freelancerType = rowData[typeCol];
  var freelancerEmail = rowData[emailCol];
  var freelancerName = rowData[nameCol];

  // Find or create sheet for this type
  var db = SpreadsheetApp.getActiveSpreadsheet();
  var typeSheet;
  try {
    typeSheet = db.getSheetByName(freelancerType);
    if (!typeSheet) {
      typeSheet = db.insertSheet(freelancerType);
      typeSheet.appendRow(headers);
    }
  } catch (err) {
    typeSheet = db.insertSheet(freelancerType);
    typeSheet.appendRow(headers);
  }
  typeSheet.appendRow(rowData);

  // Send onboarding email based on role
  sendOnboardingEmail(freelancerType, freelancerEmail, freelancerName);

  // Add other smart onboarding actions here
  smartOnboardingActions(freelancerType, rowData, headers);
}


/**
 * Sends a customized onboarding email based on freelancer role
 */
function sendOnboardingEmail(role, email, name) {
  var subject = 'Welcome to the Team!';
  var body = '';
  switch (role) {
    case 'Videographer':
      body = 'Hi ' + name + ',\n\nWelcome aboard as a Videographer! Please review our video guidelines and upload your demo reel.';
      break;
    case 'Developer':
      body = 'Hi ' + name + ',\n\nWelcome to our Developer network! Please join our Slack channel and review the onboarding docs.';
      break;
    case 'Animator':
      body = 'Hi ' + name + ',\n\nExcited to have you as an Animator! Please share your latest animation portfolio.';
      break;
    case 'Graphic Designer':
      body = 'Hi ' + name + ',\n\nWelcome as a Graphic Designer! Please review our brand assets and submit your design samples.';
      break;
    case 'Instructor':
      body = 'Hi ' + name + ',\n\nThank you for joining as an Instructor! Please complete your teaching profile.';
      break;
    case 'Tech Instructor':
      body = 'Hi ' + name + ',\n\nWelcome as a Tech Instructor! Please review our curriculum and teaching resources.';
      break;
    case 'Accounting Instructor':
      body = 'Hi ' + name + ',\n\nWelcome as an Accounting Instructor! Please upload your certifications and teaching plan.';
      break;
    case 'Machine Learning Instructor':
      body = 'Hi ' + name + ',\n\nWelcome as a Machine Learning Instructor! Please join our ML forum and share your latest research.';
      break;
    default:
      body = 'Hi ' + name + ',\n\nWelcome to our freelance network! We will be in touch with next steps.';
  }
  MailApp.sendEmail({
    to: email,
    subject: subject,
    body: body
  });
}

/**
 * Add other smart onboarding actions here (e.g., add to mailing list, notify admin, etc.)
 */
function smartOnboardingActions(role, rowData, headers) {
  // Example: Notify admin for certain roles
  var adminEmail = 'admin@yourcompany.com';
  if (role === 'Machine Learning Instructor' || role === 'Tech Instructor') {
    var name = rowData[headers.indexOf('Name')];
    var email = rowData[headers.indexOf('Email')];
    MailApp.sendEmail({
      to: adminEmail,
      subject: 'New High-Tech Instructor Onboarded',
      body: 'A new ' + role + ' has joined: ' + name + ' (' + email + ')'
    });
  }
  // Add more smart actions as needed
}

/**
 * Setup instructions:
 * 1. Create a Google Form with the above fields and link to a Sheet.
 * 2. In the Sheet, go to Extensions > Apps Script, paste this code.
 * 3. Set a trigger: Edit > Current project's triggers > Add Trigger > onFormSubmit > From spreadsheet > On form submit.
 * 4. Each freelancer submission will be auto-sorted into a sheet by type and receive a custom onboarding email.
 */
