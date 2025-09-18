/**
 * Google Apps Script to list all files and folders in Google Drive in a text tree format
 * and allow the user to rearrange them by specifying moves in the sheet.
 */

function onOpen() {
  var ui = SpreadsheetApp.getUi();
  ui.createMenu('Drive Tools')
    .addItem('List Drive Tree', 'listDriveTree')
    .addItem('Rearrange Drive', 'rearrangeDriveFromSheet')
    .addToUi();
}

/**
 * Lists all files and folders in Google Drive in a text tree format in the active sheet
 */
function listDriveTree() {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  sheet.clear();
  sheet.appendRow(['Text Tree Format of Google Drive']);
  var tree = buildDriveTree(DriveApp.getRootFolder(), '', []);
  tree.forEach(function(line) {
    sheet.appendRow([line]);
  });
  sheet.appendRow(['', '', 'To rearrange, fill below:']);
  sheet.appendRow(['File/Folder Name', 'Current Parent', 'New Parent']);
}

/**
 * Recursively builds a text tree of Drive contents
 */
function buildDriveTree(folder, prefix, lines) {
  lines.push(prefix + folder.getName() + ' [Folder]');
  var folders = folder.getFolders();
  while (folders.hasNext()) {
    var subFolder = folders.next();
    buildDriveTree(subFolder, prefix + '  ', lines);
  }
  var files = folder.getFiles();
  while (files.hasNext()) {
    var file = files.next();
    lines.push(prefix + '  ' + file.getName() + ' [File]');
  }
  return lines;
}

/**
 * Rearranges files/folders based on instructions in the sheet
 * User should fill in: File/Folder Name, Current Parent, New Parent
 */
function rearrangeDriveFromSheet() {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  var data = sheet.getDataRange().getValues();
  for (var i = 0; i < data.length; i++) {
    if (data[i][0] === 'File/Folder Name') {
      for (var j = i + 1; j < data.length; j++) {
        var name = data[j][0];
        var currentParent = data[j][1];
        var newParent = data[j][2];
        if (name && newParent) {
          moveDriveItem(name, currentParent, newParent);
        }
      }
      break;
    }
  }
  SpreadsheetApp.getUi().alert('Rearrangement complete!');
}

/**
 * Moves a file or folder from current parent to new parent
 */
function moveDriveItem(name, currentParentName, newParentName) {
  var currentParent = findFolderByName(currentParentName);
  var newParent = findFolderByName(newParentName);
  if (!newParent) throw 'New parent folder not found: ' + newParentName;
  // Try to find file or folder in current parent
  var item = findFileOrFolderInParent(name, currentParent);
  if (!item) throw 'Item not found: ' + name + ' in ' + currentParentName;
  if (item instanceof Folder) {
    newParent.addFolder(item);
    if (currentParent) currentParent.removeFolder(item);
  } else {
    newParent.addFile(item);
    if (currentParent) currentParent.removeFile(item);
  }
}

/**
 * Finds a folder by name (searches entire Drive)
 */
function findFolderByName(name) {
  if (!name || name === 'My Drive' || name === 'Root') return DriveApp.getRootFolder();
  var folders = DriveApp.getFoldersByName(name);
  return folders.hasNext() ? folders.next() : null;
}

/**
 * Finds a file or folder by name in a parent folder
 */
function findFileOrFolderInParent(name, parent) {
  if (!parent) parent = DriveApp.getRootFolder();
  var folders = parent.getFoldersByName(name);
  if (folders.hasNext()) return folders.next();
  var files = parent.getFilesByName(name);
  if (files.hasNext()) return files.next();
  return null;
}
