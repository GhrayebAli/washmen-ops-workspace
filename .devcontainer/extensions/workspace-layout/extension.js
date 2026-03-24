const vscode = require('vscode');

function activate(context) {
  setTimeout(async () => {
    try {
      await vscode.commands.executeCommand(
        'simpleBrowser.api.open',
        vscode.Uri.parse('http://localhost:4000'),
        { viewColumn: vscode.ViewColumn.One, preserveFocus: true }
      );
      await vscode.commands.executeCommand(
        'simpleBrowser.api.open',
        vscode.Uri.parse('http://localhost:3000'),
        { viewColumn: vscode.ViewColumn.Two, preserveFocus: true }
      );
      await vscode.commands.executeCommand('workbench.action.closeSidebar');
    } catch (err) {
      console.log('Workspace layout: waiting for services...', err.message);
      setTimeout(() => activate(context), 10000);
    }
  }, 8000);
}

function deactivate() {}
module.exports = { activate, deactivate };
