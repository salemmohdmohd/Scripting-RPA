/**
 * Google Apps Script for Google Form Personality Test Gamification
 * - Sends answers to both recipient (user) and sender (form owner) on submission
 * - Uses researched personality test questions
 */

// Personality test questions (recommended for Google Form)
// 1. I enjoy social gatherings.
// 2. I like to try new things.
// 3. I prefer planning over spontaneity.
// 4. I get stressed easily.
// 5. I am detail-oriented.
// 6. I am comfortable leading groups.
// 7. I value creativity.
// 8. I am empathetic to others.
// 9. I adapt quickly to change.
// 10. I am motivated by achievement.
// (Add these as multiple choice or scale questions in your Google Form)

/**
 * Triggered on form submission. Sends answers to user and form owner.
 */
function onFormSubmit(e) {
  var responses = e.values;
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  var headers = sheet.getDataRange().getValues()[0];
  var recipientEmail = responses[headers.indexOf('Email Address')]; // Add an 'Email Address' field to your form
  var senderEmail = Session.getActiveUser().getEmail();

  var answerText = 'Thank you for completing the Personality Test!\n\nYour answers:\n';
  for (var i = 1; i < responses.length; i++) {
    answerText += headers[i] + ': ' + responses[i] + '\n';
  }

  // Simple gamification feedback
  answerText += '\nFun Fact: Your answers show you are '; // Add basic scoring or random fun feedback
  var score = Math.floor(Math.random() * 3);
  if (score === 0) answerText += 'an Adventurer!';
  else if (score === 1) answerText += 'a Planner!';
  else answerText += 'a Creative Thinker!';

  // Send to recipient
  MailApp.sendEmail({
    to: recipientEmail,
    subject: 'Your Personality Test Results',
    body: answerText
  });
  // Send to sender
  MailApp.sendEmail({
    to: senderEmail,
    subject: 'Personality Test Submission Received',
    body: 'A new submission was received:\n\n' + answerText
  });
}

/**
 * To set up:
 * 1. Create a Google Form with the above questions and an 'Email Address' field.
 * 2. Link the Form to a Google Sheet.
 * 3. In the Sheet, go to Extensions > Apps Script, paste this code.
 * 4. Set a trigger: Edit > Current project's triggers > Add Trigger > onFormSubmit > From spreadsheet > On form submit.
 */
