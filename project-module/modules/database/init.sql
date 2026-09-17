USE testdb;
-- 테스트 목적의 테이블 생성
CREATE TABLE IF NOT EXISTS tnote (
  idx           INT           NOT NULL  AUTO_INCREMENT,
  subject       VARCHAR(100)  NOT NULL,
  content       TEXT          NOT NULL,
  PRIMARY KEY (idx)
);