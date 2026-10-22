import Base
import ../gui.bend as Coordinator
import ../gui_quota.bend as QuotaLifecycle
import ../gui_attachments.bend as AttachmentLifecycle

# These suites have no shared persistent fixture or command-line child route.
# Their GUI state/channel assertions are distinct from actual UI acceptance.
def main() -> IO(Unit):
  do IO<Unit>:
    Coordinator.main()
    QuotaLifecycle.main()
    AttachmentLifecycle.main()
