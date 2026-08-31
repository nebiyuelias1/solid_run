class CreateWorkflowRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :workflow_runs do |t|
      t.string :repo
      t.string :event_type
      t.string :branch
      t.string :commit_sha
      t.string :commit_message
      t.string :author
      t.string :status
      t.text :workflow_files
      t.string :target_url
      t.float :duration_seconds
      t.text :logs
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end
  end
end
