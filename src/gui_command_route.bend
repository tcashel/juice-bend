import Base

# Equality dispatch keeps command strings out of nested list patterns. The
# caller still matches each command's exact operand shape before using a route.
def read_kind(+command: String) -> U32:
  Bool.pick(U32,String.eq(command,"quota-view"),0,
    Bool.pick(U32,String.eq(command,"brief-prepare") || String.eq(command,"brief-check"),1,
      Bool.pick(U32,String.eq(command,"latest-view"),2,
        Bool.pick(U32,String.eq(command,"attachment-roots") || String.eq(command,"captured-attachment"),3,
          Bool.pick(U32,String.eq(command,"attachments") || String.eq(command,"session-scope") ||
            String.eq(command,"why-scope") || String.eq(command,"activity-scope") ||
            String.eq(command,"relations-scope") || String.eq(command,"relations-page") ||
            String.eq(command,"result-link-events") || String.eq(command,"result-link-page"),4,
            Bool.pick(U32,String.eq(command,"library-usage-v1") || String.eq(command,"library-usage-capture-v1"),6,5))))))

def write_kind(+command: String) -> U32:
  Bool.pick(U32,String.eq(command,"export-atif"),0,
    Bool.pick(U32,String.eq(command,"quota-view"),1,
      Bool.pick(U32,String.eq(command,"export-displayed") || String.eq(command,"export-brief-text"),2,
        Bool.pick(U32,String.eq(command,"source-add") || String.eq(command,"source-disable"),3,
          Bool.pick(U32,String.eq(command,"refresh-preferences"),4,
            Bool.pick(U32,String.eq(command,"refresh-preferences-set"),5,
              Bool.pick(U32,String.eq(command,"capture-attachment") || String.eq(command,"attachment-root-add") ||
                String.eq(command,"attachment-root-enable") || String.eq(command,"attachment-root-disable") ||
                String.eq(command,"export-captured-attachment"),6,7)))))))
