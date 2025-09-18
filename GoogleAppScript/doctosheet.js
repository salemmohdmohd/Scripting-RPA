/**
 * Google Apps Script to convert current Google Doc content to Google Sheets
 * This script extracts content from the active Google Doc and creates a new Google Sheets
 * with the document content organized in a structured format.
 */

/**
 * Main function to convert the current Google Doc to Google Sheets
 * This function should be run from the Google Apps Script editor
 */
function convertDocToSheets() {
  try {
    // Get the active document
    const doc = DocumentApp.getActiveDocument();

    if (!doc) {
      throw new Error('No active document found. Please open a Google Doc and run this script from the Apps Script editor.');
    }

    // Extract content from the document
    const documentContent = extractDocumentContent(doc);

    // Create a new Google Sheets with the content
    const spreadsheet = createSpreadseetWithContent(documentContent, doc.getName());

    // Show success message with link to the new spreadsheet
    const ui = DocumentApp.getUi();
    ui.alert(
      'Conversion Complete!\n\n' +
      `Your document has been converted to a Google Sheets.\nSpreadsheet: ${spreadsheet.getName()}\nURL: ${spreadsheet.getUrl()}`
    );

    Logger.log(`Document converted successfully: ${spreadsheet.getUrl()}`);

  } catch (error) {
  Logger.log(`Error converting document: ${error.toString()}`);
    const ui = DocumentApp.getUi();
  ui.alert('Error\nFailed to convert document: ' + error.message);
  }
}

/**
 * Extract structured content from the Google Document
 * @param {GoogleAppsScript.Document.Document} doc - The Google Document
 * @returns {Array} Array of content objects with text and formatting info
 */
function extractDocumentContent(doc) {
  const body = doc.getBody();
  const paragraphs = body.getParagraphs();
  const content = [];

  // Add document title
  content.push({
    type: 'title',
    text: doc.getName(),
    level: 0
  });

  paragraphs.forEach((paragraph, index) => {
    const text = paragraph.getText().trim();

    // Skip empty paragraphs
    if (text === '') return;

    const heading = paragraph.getHeading();
    let type = 'paragraph';
    let level = 0;

    // Determine content type based on heading level
    switch (heading) {
      case DocumentApp.ParagraphHeading.TITLE:
        type = 'title';
        level = 0;
        break;
      case DocumentApp.ParagraphHeading.HEADING1:
        type = 'heading';
        level = 1;
        break;
      case DocumentApp.ParagraphHeading.HEADING2:
        type = 'heading';
        level = 2;
        break;
      case DocumentApp.ParagraphHeading.HEADING3:
        type = 'heading';
        level = 3;
        break;
      case DocumentApp.ParagraphHeading.HEADING4:
        type = 'heading';
        level = 4;
        break;
      case DocumentApp.ParagraphHeading.HEADING5:
        type = 'heading';
        level = 5;
        break;
      case DocumentApp.ParagraphHeading.HEADING6:
        type = 'heading';
        level = 6;
        break;
      default:
        type = 'paragraph';
        level = 0;
    }

    content.push({
      type: type,
      text: text,
      level: level,
      index: index
    });
  });

  return content;
}

/**
 * Create a new Google Sheets and populate it with the document content
 * @param {Array} content - Array of content objects from the document
 * @param {string} docName - Name of the original document
 * @returns {GoogleAppsScript.Spreadsheet.Spreadsheet} The created spreadsheet
 */
function createSpreadseetWithContent(content, docName) {
  // Create a new spreadsheet
  const spreadsheetName = `${docName} - Converted from Doc`;
  const spreadsheet = SpreadsheetApp.create(spreadsheetName);
  const sheet = spreadsheet.getActiveSheet();

  // Set up headers
  sheet.getRange(1, 1, 1, 4).setValues([['Type', 'Level', 'Content', 'Index']]);
  sheet.getRange(1, 1, 1, 4).setFontWeight('bold');
  sheet.getRange(1, 1, 1, 4).setBackground('#e6f3ff');

  // Populate content
  const dataRows = content.map(item => [
    item.type,
    item.level,
    item.text,
    item.index || 0
  ]);

  if (dataRows.length > 0) {
    sheet.getRange(2, 1, dataRows.length, 4).setValues(dataRows);
  }

  // Format the sheet
  formatSpreadsheet(sheet, content.length + 1);

  return spreadsheet;
}

/**
 * Apply formatting to the spreadsheet for better readability
 * @param {GoogleAppsScript.Spreadsheet.Sheet} sheet - The sheet to format
 * @param {number} numRows - Total number of rows with data
 */
function formatSpreadsheet(sheet, numRows) {
  // Auto-resize columns
  sheet.autoResizeColumns(1, 4);

  // Set column widths for better readability
  sheet.setColumnWidth(1, 100); // Type
  sheet.setColumnWidth(2, 80);  // Level
  sheet.setColumnWidth(3, 500); // Content
  sheet.setColumnWidth(4, 80);  // Index

  // Add borders
  sheet.getRange(1, 1, numRows, 4).setBorder(true, true, true, true, true, true);

  // Apply conditional formatting for different content types
  const typeRange = sheet.getRange(2, 1, numRows - 1, 1);

  // Title formatting
  const titleRule = SpreadsheetApp.newConditionalFormatRule()
    .whenTextEqualTo('title')
    .setBackground('#ffeb3b')
    .setRanges([typeRange])
    .build();

  // Heading formatting
  const headingRule = SpreadsheetApp.newConditionalFormatRule()
    .whenTextEqualTo('heading')
    .setBackground('#c8e6c9')
    .setRanges([typeRange])
    .build();

  // Paragraph formatting
  const paragraphRule = SpreadsheetApp.newConditionalFormatRule()
    .whenTextEqualTo('paragraph')
    .setBackground('#ffffff')
    .setRanges([typeRange])
    .build();

  sheet.setConditionalFormatRules([titleRule, headingRule, paragraphRule]);

  // Freeze header row
  sheet.setFrozenRows(1);
}

/**
 * Creates a menu in the Google Doc to easily access the conversion function
 * This function runs automatically when the document is opened
 */
function onOpen() {
  const ui = DocumentApp.getUi();
  ui.createMenu('Document Tools')
    .addItem('Convert to Google Sheets', 'convertDocToSheets')
    .addToUi();
}

/**
 * Alternative function that can be used to convert any Google Doc by ID
 * @param {string} docId - The ID of the Google Doc to convert
 */
function convertDocByIdToSheets(docId) {
  try {
    const doc = DocumentApp.openById(docId);

    if (!doc) {
      throw new Error(`Document with ID ${docId} not found or not accessible.`);
    }

    const documentContent = extractDocumentContent(doc);
    const spreadsheet = createSpreadseetWithContent(documentContent, doc.getName());

    Logger.log(`Document converted successfully: ${spreadsheet.getUrl()}`);
    return spreadsheet.getUrl();

  } catch (error) {
  Logger.log(`Error converting document by ID: ${error.toString()}`);
    throw error;
  }
}