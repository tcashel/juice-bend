import Base
import ../reader_polish.bend as Reader
import ../ui.bend as Editing
import ../keyboard_selection.bend as Keyboard
import ../ui_attachments.bend as Attachments
import ../polish.bend as Polish
import ../window_layout.bend as Layout

def main() -> IO(Unit):
  do IO<Unit>:
    Reader.main()
    Editing.main()
    Keyboard.main()
    Attachments.main()
    Polish.main()
    Layout.main()
