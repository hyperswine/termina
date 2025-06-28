# Termina

A spotlight + shell like fusion concept GUI. Also has a text editor and some mini apps like a key visualizer as we type.
The basic GUI will be the main desktop like shell with nothing there but a dynamic background.
Press CTL + K to open the spotlight like thing which is like a modal similar to the actual spotlight or raycast.
The modal would show a wide text field like

[>                                 ]
| Getting Started
| Previous Command: ls
| Previous Search: file.txt

with a drop down

[$                                 ]
| ls: /home
|       readme.txt
|       file.txt
|       newdir/
|         readme.txt
|         ...

Has the basic features of searching for files, inputting CLI Commands like ls.
Has a mini filesystem of the type

File : Directory [File] | File Content
Content : String

With phoenix ecto sqlite persistence.

List of commands:
ls <path?> - creates a new pane in the dropdown menu below the modal and shows the list of files in the cwd
cd <path?> - change cwd, to /home if path not specified
cat <path> - show file content
show <path> - alias for cat
rm <path> - remove a file, including a directory. No -r required or rmdir required
touch <path> - creates a new file or directory, including any parent directories if needed. E.g. touch /home/mydir or touch /home/file.txt
edit <path> - opens up the text editor on the desktop view and closes the modal

Note some of the commands like cat, touch, edit only work on File not Directory. So if the path refers to directory then it will print an error

The modal search dialog view has two modes
The first mode is the ">" mode. Which is an intelligent file search mode that can search based on filenames and content as well as any commands
The second mode is the "$" mode. Which is the pure shell mode. Here we can run commands like ls directly
By default the modal text field is auto filled with ">" for the intelligent file search. The user can easily backspace and write $ instead
Without the > or $ mode we have the empty mode. In the empty mode we have the "help mode" which shows a dropdown pane of common options to do

The UI looks quite modern like apple's spotlight. The desktop view also looks minimal and is basically just a changing gradient color that is meant to be replaced with a mini app like the text editor or key visualizer when called by the modal searcher

The editor should have a save button that saves the file. At the top left corner.
