CREATE TEMP TABLE tmp_scope_evals AS (
  SELECT DISTINCT e.id AS eval FROM jobsetevals AS e INNER JOIN jobsets AS js ON e.jobset_id = js.id
  WHERE js.project = 'nixpkgs' AND js.name = 'trunk'
    AND date_part('epoch',now()) - e.timestamp < 3.3e7
);
ALTER TABLE tmp_scope_evals ADD CONSTRAINT pk_eval PRIMARY KEY (eval);

CREATE TEMP TABLE tmp_scope_builds AS (
  SELECT DISTINCT m.build AS build FROM jobsetevalmembers AS m JOIN tmp_scope_evals AS scope ON m.eval = scope.eval
);
ALTER TABLE tmp_scope_builds ADD CONSTRAINT pk_build PRIMARY KEY (build);

CREATE TABLE tmp_jobsetevals as (SELECT e.* FROM jobsetevals as e INNER JOIN tmp_scope_evals AS scope ON e.id = scope.eval);
CREATE TABLE tmp_jobsetevalinputs as (SELECT ei.* FROM jobsetevalinputs as ei INNER JOIN tmp_scope_evals AS scope ON ei.eval = scope.eval);
CREATE TABLE tmp_jobsetevalmembers as (SELECT em.* FROM jobsetevalmembers as em INNER JOIN tmp_scope_evals AS scope ON em.eval = scope.eval);
CREATE TABLE tmp_builds as (SELECT b.* FROM builds as b INNER JOIN tmp_scope_builds AS scope ON b.id = scope.build);
CREATE TABLE tmp_buildsteps AS (SELECT bs.* FROM buildsteps AS bs INNER JOIN tmp_scope_builds AS scope ON bs.build = scope.build);
