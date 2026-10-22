import Base
import ../gui_quota_model.bend as QuotaModel
import ../gui_quota_presentation.bend as QuotaPresentation
import ../gui_quota_ui.bend as QuotaControls
import ../gui_attachments_model.bend as AttachmentModel
import ../ui_attachments.bend as AttachmentControls
import ../transcript_format.bend as TranscriptFormat
import ../window_layout.bend as WindowLayout
import ../polish.bend as Polish

# Run the existing pure/state checks together to avoid repeated native builds.
# No assertions are replaced; this does not launch or observe a native window.
def main() -> IO(Unit):
  do IO<Unit>:
    QuotaModel.main()
    QuotaPresentation.main()
    QuotaControls.main()
    AttachmentModel.main()
    AttachmentControls.main()
    TranscriptFormat.main()
    WindowLayout.main()
    Polish.main()
