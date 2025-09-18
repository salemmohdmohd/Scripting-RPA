/**
 * Google Apps Script for PTO Management via Google Form and Sheet
 * - Employees submit PTO requests via Form
 * - HR approves/rejects in Sheet
 * - Approved PTO is added to company Google Calendar
 */

// Recommended Google Form fields:
// - Employee Name
// - Employee Email
// - PTO Start Date
// - PTO End Date
// - PTO Type (Vacation, Sick, etc.)
// - Comments
// (Form responses should be linked to a Google Sheet with a 'Status' column for HR to update)

/**
 * Triggered when HR updates the 'Status' column in the Sheet
 * If status is 'Approved', adds PTO event to company calendar
 */
function onEdit(e) {
  var sheet = e.range.getSheet();
  var statusCol = getStatusColumn(sheet);
  if (e.range.getColumn() !== statusCol) return;
  var status = e.value;
  if (status !== 'Approved') return;

  var row = e.range.getRow();
  var data = sheet.getRange(row, 1, 1, sheet.getLastColumn()).getValues()[0];
  var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];

  var employeeName = data[headers.indexOf('Employee Name')];
  var employeeEmail = data[headers.indexOf('Employee Email')];
  var startDate = new Date(data[headers.indexOf('PTO Start Date')]);
  var endDate = new Date(data[headers.indexOf('PTO End Date')]);
  var ptoType = data[headers.indexOf('PTO Type')];
  var comments = data[headers.indexOf('Comments')];

  addPTOToCalendar(employeeName, employeeEmail, startDate, endDate, ptoType, comments);
}

/**
 * Finds the 'Status' column index in the sheet
 */
function getStatusColumn(sheet) {
  var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  for (var i = 0; i < headers.length; i++) {
    if (headers[i] === 'Status') return i + 1;
  }
  throw 'Status column not found.';
}

/**
 * Adds PTO event to the company Google Calendar
 * @param {string} name
 * @param {string} email
 * @param {Date} startDate
 * @param {Date} endDate
 * @param {string} type
 * @param {string} comments
 */
function addPTOToCalendar(name, email, startDate, endDate, type, comments) {
  var calendarId = 'YOUR_COMPANY_CALENDAR_ID@group.calendar.google.com'; // <-- Replace with your calendar ID
  var calendar = CalendarApp.getCalendarById(calendarId);
  var title = name + ' PTO (' + type + ')';
  var description = 'Employee: ' + name + '\nEmail: ' + email + '\nType: ' + type + '\nComments: ' + comments;
  calendar.createEvent(title, startDate, endDate, {description: description, guests: email});
}

/**
 * Setup instructions:
 * 1. Create a Google Form with the above fields and link to a Sheet.
 * 2. Add a 'Status' column for HR to update (e.g., Pending, Approved, Rejected).
 * 3. In the Sheet, go to Extensions > Apps Script, paste this code.
 * 4. Set a trigger: Edit > Current project's triggers > Add Trigger > onEdit > From spreadsheet > On edit.
 * 5. Replace 'YOUR_COMPANY_CALENDAR_ID@group.calendar.google.com' with your actual calendar ID.
 */
