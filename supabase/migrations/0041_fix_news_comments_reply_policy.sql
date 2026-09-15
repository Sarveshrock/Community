-- 0041_fix_news_comments_reply_policy.sql
-- BUG FIX: news_comments_insert (0040) rejected every reply with 403.
--
-- Its EXISTS subquery aliased news_comments as `p` and then referenced
-- `parent_comment_id`/`article_url` unqualified inside that subquery.
-- Because those column names also exist on `p`, Postgres resolves them to
-- the subquery's own row (the innermost scope), not the row being
-- inserted — collapsing the check to `p.id = p.parent_comment_id`, which
-- is never true for any real row. So the "is this parent_comment_id a real
-- top-level comment on this article?" check always failed, and every
-- reply was blocked by RLS regardless of validity. Top-level comments
-- (parent_comment_id is null) were unaffected — they short-circuit before
-- ever reaching that subquery.
--
-- Fix: qualify the two outer-row references with the table name itself so
-- they correlate to the row being inserted, not to `p`.

drop policy if exists news_comments_insert on news_comments;

create policy news_comments_insert on news_comments for insert
  with check (
    author_id = auth.uid()
    and (
      parent_comment_id is null
      or exists (
        select 1 from news_comments p
        where p.id = news_comments.parent_comment_id
          and p.article_url = news_comments.article_url
          and p.parent_comment_id is null
      )
    )
  );
