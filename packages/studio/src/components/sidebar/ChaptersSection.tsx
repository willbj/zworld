import { useEffect, useState, useCallback } from "react";
import { fetchJson } from "../../hooks/use-api";
import { useChatStore } from "../../store/chat";
import { SidebarCard } from "./SidebarCard";
import { cn } from "../../lib/utils";
import { CheckCircle2, XCircle, FileText, ChevronDown, Loader2, AlertTriangle } from "lucide-react";

interface ChapterMeta {
  number: number;
  title: string;
  status: string;
  wordCount: number;
  auditIssues?: string[];
  reviewNote?: string;
}

// All statuses from ChapterStatusSchema
const STATUS_INDICATOR: Record<string, { symbol: string; color: string; label: string }> = {
  approved:          { symbol: "✓", color: "text-emerald-500",          label: "已批准" },
  "ready-for-review":{ symbol: "◆", color: "text-amber-500",            label: "待复核" },
  "audit-passed":    { symbol: "◆", color: "text-amber-500",            label: "审计通过" },
  "audit-failed":    { symbol: "✕", color: "text-destructive",          label: "审计失败" },
  "state-degraded":  { symbol: "⚠", color: "text-yellow-600",           label: "状态异常" },
  revising:          { symbol: "↺", color: "text-blue-500",             label: "修订中" },
  auditing:          { symbol: "…", color: "text-muted-foreground",     label: "审计中" },
  drafting:          { symbol: "…", color: "text-muted-foreground",     label: "写作中" },
  drafted:           { symbol: "○", color: "text-muted-foreground",     label: "草稿" },
  "card-generated":  { symbol: "○", color: "text-muted-foreground/50",  label: "已建卡" },
  imported:          { symbol: "◇", color: "text-blue-500",             label: "已导入" },
  rejected:          { symbol: "✕", color: "text-destructive/60",       label: "已拒绝" },
  published:         { symbol: "★", color: "text-emerald-600",          label: "已发布" },
};

// Parse "[critical] description" or "[warning] description" strings
function parseIssue(raw: string): { severity: "critical" | "warning" | "info"; description: string } {
  const m = raw.match(/^\[(critical|warning|info)\]\s*(.*)/s);
  if (m) return { severity: m[1] as "critical" | "warning" | "info", description: m[2]!.trim() };
  return { severity: "info", description: raw.trim() };
}

const CAN_APPROVE = new Set(["ready-for-review", "audit-failed", "audit-passed", "state-degraded"]);
const CAN_REJECT  = new Set(["ready-for-review", "audit-failed", "audit-passed", "approved", "state-degraded"]);

interface ChapterDetailProps {
  bookId: string;
  chapter: ChapterMeta;
  onDone: () => void;
}

function ChapterDetail({ bookId, chapter, onDone }: ChapterDetailProps) {
  const bumpBookDataVersion = useChatStore((s) => s.bumpBookDataVersion);
  const openChapterArtifact = useChatStore((s) => s.openChapterArtifact);
  const [loading, setLoading] = useState<"approve" | "reject" | null>(null);
  const [confirmReject, setConfirmReject] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const issues = (chapter.auditIssues ?? []).map(parseIssue);
  const criticals = issues.filter((i) => i.severity === "critical");
  const warnings  = issues.filter((i) => i.severity === "warning");

  const handleApprove = useCallback(async () => {
    setLoading("approve");
    setError(null);
    try {
      await fetchJson(`/books/${bookId}/chapters/${chapter.number}/approve`, { method: "POST" });
      bumpBookDataVersion();
      onDone();
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(null);
    }
  }, [bookId, chapter.number, bumpBookDataVersion, onDone]);

  const handleReject = useCallback(async () => {
    setLoading("reject");
    setError(null);
    try {
      await fetchJson(`/books/${bookId}/chapters/${chapter.number}/reject`, { method: "POST" });
      bumpBookDataVersion();
      onDone();
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(null);
      setConfirmReject(false);
    }
  }, [bookId, chapter.number, bumpBookDataVersion, onDone]);

  const ind = STATUS_INDICATOR[chapter.status] ?? { symbol: "○", color: "text-muted-foreground", label: chapter.status };

  return (
    <div className="mt-1 mb-2 rounded-xl border border-border/40 bg-card/50 text-xs overflow-hidden">
      {/* status bar */}
      <div className="flex items-center justify-between px-3 py-2 border-b border-border/20">
        <span className={cn("font-medium", ind.color)}>{ind.symbol} {ind.label}</span>
        <button
          onClick={() => openChapterArtifact(chapter.number)}
          className="flex items-center gap-1 text-muted-foreground hover:text-foreground transition-colors"
          title="查看章节正文"
        >
          <FileText size={11} />
          <span>查看正文</span>
        </button>
      </div>

      {/* reviewNote */}
      {chapter.reviewNote && (
        <div className="px-3 py-2 text-muted-foreground border-b border-border/20 leading-relaxed">
          {chapter.reviewNote}
        </div>
      )}

      {/* issues */}
      {issues.length > 0 ? (
        <div className="divide-y divide-border/20">
          {criticals.map((issue, i) => (
            <div key={`c-${i}`} className="px-3 py-2 bg-destructive/5 flex items-start gap-1.5">
              <span className="shrink-0 mt-0.5 rounded px-1 py-0.5 text-[10px] font-medium bg-destructive/15 text-destructive leading-none">严重</span>
              <span className="text-foreground/85 leading-snug">{issue.description}</span>
            </div>
          ))}
          {warnings.map((issue, i) => (
            <div key={`w-${i}`} className="px-3 py-2 flex items-start gap-1.5">
              <span className="shrink-0 mt-0.5 rounded px-1 py-0.5 text-[10px] font-medium bg-yellow-500/15 text-yellow-700 dark:text-yellow-400 leading-none">警告</span>
              <span className="text-foreground/75 leading-snug">{issue.description}</span>
            </div>
          ))}
        </div>
      ) : (
        chapter.status !== "approved" && (
          <div className="px-3 py-2 text-muted-foreground/60 italic">暂无审计问题</div>
        )
      )}

      {/* error */}
      {error && (
        <div className="px-3 py-2 text-destructive bg-destructive/5 border-t border-border/20">{error}</div>
      )}

      {/* actions */}
      {(CAN_APPROVE.has(chapter.status) || CAN_REJECT.has(chapter.status)) && (
        <div className="px-3 py-2.5 border-t border-border/20 flex items-center gap-2">
          {CAN_APPROVE.has(chapter.status) && !confirmReject && (
            <button
              onClick={handleApprove}
              disabled={loading !== null}
              className="flex items-center gap-1 rounded-lg px-2.5 py-1.5 text-[11px] font-medium bg-emerald-500/10 text-emerald-700 dark:text-emerald-400 hover:bg-emerald-500/20 transition-colors disabled:opacity-50"
            >
              {loading === "approve" ? <Loader2 size={11} className="animate-spin" /> : <CheckCircle2 size={11} />}
              批准
            </button>
          )}

          {CAN_REJECT.has(chapter.status) && !confirmReject && (
            <button
              onClick={() => setConfirmReject(true)}
              disabled={loading !== null}
              className="flex items-center gap-1 rounded-lg px-2.5 py-1.5 text-[11px] font-medium bg-destructive/10 text-destructive hover:bg-destructive/20 transition-colors disabled:opacity-50"
            >
              <XCircle size={11} />
              拒绝
            </button>
          )}

          {/* rejection confirmation */}
          {confirmReject && (
            <div className="flex-1">
              <div className="flex items-start gap-1.5 mb-2 text-destructive/80">
                <AlertTriangle size={11} className="shrink-0 mt-0.5" />
                <span className="leading-snug">
                  将删除第 {chapter.number} 章及所有后续章节，状态回滚至第 {chapter.number - 1} 章。不可撤销。
                </span>
              </div>
              <div className="flex gap-2">
                <button
                  onClick={handleReject}
                  disabled={loading !== null}
                  className="flex items-center gap-1 rounded-lg px-2.5 py-1.5 text-[11px] font-medium bg-destructive text-white hover:bg-destructive/90 transition-colors disabled:opacity-50"
                >
                  {loading === "reject" ? <Loader2 size={11} className="animate-spin" /> : null}
                  确认拒绝
                </button>
                <button
                  onClick={() => setConfirmReject(false)}
                  disabled={loading !== null}
                  className="rounded-lg px-2.5 py-1.5 text-[11px] text-muted-foreground hover:text-foreground hover:bg-secondary/50 transition-colors disabled:opacity-50"
                >
                  取消
                </button>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

interface ChaptersSectionProps {
  readonly bookId: string;
  readonly isZh: boolean;
}

export function ChaptersSection({ bookId, isZh }: ChaptersSectionProps) {
  const [chapters, setChapters] = useState<ReadonlyArray<ChapterMeta>>([]);
  const [selected, setSelected] = useState<number | null>(null);
  const bookDataVersion = useChatStore((s) => s.bookDataVersion);

  useEffect(() => {
    fetchJson<{ chapters: ChapterMeta[] }>(`/books/${bookId}`)
      .then((data) => setChapters(data.chapters))
      .catch(() => setChapters([]));
  }, [bookId, bookDataVersion]);

  return (
    <SidebarCard title={isZh ? "章节" : "Chapters"}>
      {chapters.length === 0 ? (
        <p className="text-[15px] leading-6 text-muted-foreground/50 italic">
          {isZh ? "暂无章节" : "No chapters"}
        </p>
      ) : (
        <ul className="space-y-0.5 max-h-[420px] overflow-y-auto overflow-x-hidden">
          {chapters.map((ch) => {
            const ind = STATUS_INDICATOR[ch.status] ?? { symbol: "○", color: "text-muted-foreground", label: ch.status };
            const isSelected = selected === ch.number;
            const hasIssues = (ch.auditIssues ?? []).length > 0;
            return (
              <li key={`${ch.number}-${ch.title ?? ""}`}>
                <div
                  onClick={() => setSelected(isSelected ? null : ch.number)}
                  className={cn(
                    "flex items-center gap-2 py-1 text-[15px] leading-6 cursor-pointer rounded px-1 -mx-1 transition-colors",
                    isSelected
                      ? "text-foreground bg-secondary/60"
                      : "text-muted-foreground hover:text-foreground hover:bg-secondary/50",
                  )}
                >
                  <span className={cn("text-[13px] shrink-0", ind.color)}>{ind.symbol}</span>
                  <span className="truncate flex-1">
                    {String(ch.number).padStart(2, "0")} {ch.title || (isZh ? `第${ch.number}章` : `Chapter ${ch.number}`)}
                  </span>
                  <div className="flex items-center gap-1.5 shrink-0">
                    {hasIssues && (
                      <span className="text-[10px] text-destructive/70 font-medium">
                        {(ch.auditIssues ?? []).length}
                      </span>
                    )}
                    <span className="tabular-nums text-[13px] text-muted-foreground/50">
                      {(ch.wordCount ?? 0).toLocaleString()}
                    </span>
                    <ChevronDown
                      size={11}
                      className={cn("text-muted-foreground/40 transition-transform", isSelected && "rotate-180")}
                    />
                  </div>
                </div>
                {isSelected && (
                  <ChapterDetail
                    bookId={bookId}
                    chapter={ch}
                    onDone={() => setSelected(null)}
                  />
                )}
              </li>
            );
          })}
        </ul>
      )}
    </SidebarCard>
  );
}
