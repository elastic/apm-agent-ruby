# frozen_string_literal: true

require 'elastic_apm/sql_summarizer'

module ElasticAPM
  RSpec.describe SqlSummarizer do
    it 'summarizes selects from table' do
      result = subject.summarize('SELECT * FROM "table"')
      expect(result).to eq('SELECT FROM table')
    end

    it 'summarizes selects from table with columns' do
      result = subject.summarize('SELECT a, b FROM table')
      expect(result).to eq('SELECT FROM table')
    end

    it 'summarizes selects from table with underscore' do
      result = subject.summarize('SELECT * FROM my_table')
      expect(result).to eq('SELECT FROM my_table')
    end

    it 'simplifies advanced selects' do
      result = subject.summarize("select months.month, count(created_at) from (select DATE '2017-06-09'+(interval '1' month * generate_series(0,11)) as month, DATE '2017-06-10'+(interval '1' month * generate_series(0,11)) as next) months left outer join subscriptions on created_at < month and (soft_destroyed_at IS NULL or soft_destroyed_at >= next) and (suspended_at IS NULL OR suspended_at >= next) group by month order by month desc") # rubocop:disable Metrics/LineLength
      expect(result).to eq('SQL')
    end

    it 'summarizes inserts' do
      sql = "INSERT INTO table (a, b) VALUES ('A','B')"
      result = subject.summarize(sql)
      expect(result).to eq('INSERT INTO table')
    end

    it 'summarizes updates' do
      sql = "UPDATE table SET a = 'B' WHERE b = 'B'"
      result = subject.summarize(sql)
      expect(result).to eq('UPDATE table')
    end

    it 'summarizes deletes' do
      result = subject.summarize("DELETE FROM table WHERE b = 'B'")
      expect(result).to eq('DELETE FROM table')
    end

    it 'sumarizes transactions' do
      result = subject.summarize('BEGIN')
      expect(result).to eq('BEGIN')
      result = subject.summarize('COMMIT')
      expect(result).to eq('COMMIT')
    end

    it 'is default when unknown' do
      sql = "SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar)"
      result = subject.summarize(sql)
      expect(result).to eq 'SQL'
    end
  end
end
