/**
 * Google Apps Script to send bulk WhatsApp messages using Twilio API
 * Sheet columns: Phone Number, Message, [Other fields]
 */

function sendBulkWhatsAppMessages() {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  var data = sheet.getDataRange().getValues();
  var headers = data[0];
  var phoneCol = headers.indexOf('Phone Number');
  var messageCol = headers.indexOf('Message');
  if (phoneCol === -1 || messageCol === -1) throw 'Required columns not found.';

  var accountSid = 'YOUR_TWILIO_ACCOUNT_SID'; // <-- Replace with your Twilio Account SID
  var authToken = 'YOUR_TWILIO_AUTH_TOKEN';   // <-- Replace with your Twilio Auth Token
  var fromNumber = 'whatsapp:+YOUR_TWILIO_WHATSAPP_NUMBER'; // <-- Replace with your Twilio WhatsApp number

  for (var i = 1; i < data.length; i++) {
    var toNumber = 'whatsapp:' + data[i][phoneCol];
    var message = personalizeMessage(data[i], headers);
    sendWhatsAppViaTwilio(accountSid, authToken, fromNumber, toNumber, message);
  }
  SpreadsheetApp.getUi().alert('Bulk WhatsApp messages sent!');
}

function sendWhatsAppViaTwilio(accountSid, authToken, from, to, body) {
  var url = 'https://api.twilio.com/2010-04-01/Accounts/' + accountSid + '/Messages.json';
  var payload = {
    'To': to,
    'From': from,
    'Body': body
  };
  var options = {
    'method': 'post',
    'payload': payload,
    'headers': {
      'Authorization': 'Basic ' + Utilities.base64Encode(accountSid + ':' + authToken)
    }
  };
  UrlFetchApp.fetch(url, options);
}

/**
 * Personalizes the message using other columns if needed
 */
function personalizeMessage(row, headers) {
  var message = row[headers.indexOf('Message')];
  // Example: Add name if column exists
  var nameCol = headers.indexOf('Name');
  if (nameCol !== -1) {
    var name = row[nameCol];
    message = 'Hi ' + name + ', ' + message;
  }
  // Add more smart personalization as needed
  return message;
}

/**
 * Setup instructions:
 * 1. Create a Google Sheet with columns: Phone Number, Message, Name, etc.
 * 2. In the Sheet, go to Extensions > Apps Script, paste this code.
 * 3. Add a menu or button to run sendBulkWhatsAppMessages().
 * 4. Replace Twilio credentials with your own.
 */
