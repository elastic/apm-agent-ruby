# frozen_string_literal: true

require 'spec_helper'

module ElasticAPM
  module Normalizers
    module ActiveRecord
      RSpec.describe SqlSummarizer do
        it 'summarizes selects from table' do
          result = subject.summarize('SELECT * FROM table')
          expect(result).to eq('SELECT FROM table')
        end

        it 'summarizes selects from table with columns' do
          result = subject.summarize('SELECT a, b FROM table')
          expect(result).to eq('SELECT FROM table')
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

        it 'is nil when unknown' do
          sql = "SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar)"
          result = subject.summarize(sql)
          expect(result).to be_nil
        end
      end
    end
  end
end
