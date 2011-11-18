Sequel.migration do
  up do
    create_table :objects do
      primary_key   :id
      string         :immutable_id, :null => false, :unique => true
      string         :name
      text          :additional_info

      time          :created_at, :null => false
      time          :last_updated_at, :null => false

    end

    create_table :permission_sets do
      primary_key   :id
      string          :name, :null => false, :unique => true

      time          :created_at, :null => false
      time          :last_updated_at, :null => false

    end

    create_table :object_permission_set_map do
      primary_key   :id
      foreign_key   :object_id, :objects
      foreign_key   :permission_set_id, :permission_sets
    end

    create_table :permissions do
      primary_key   :id
      foreign_key   :permission_set_id, :permission_sets
      string          :name, :null => false

      time          :created_at, :null => false
      time          :last_updated_at, :null => false

      unique        ([:permission_set_id, :name])

    end

    create_table :access_control_entries do
      primary_key   :id
      foreign_key   :object_id, :objects
      foreign_key   :permission_id, :permissions

      time          :created_at, :null => false
      time          :last_updated_at, :null => false

      unique        ([:object_id, :permission_id])
    end

    create_table :ace_subject_map do
      primary_key   :id
      foreign_key   :access_control_entry_id, :access_control_entries
      foreign_key   :subject_id, :subjects
    end

    create_table :subjects do
      primary_key   :id
      string         :immutable_id, :null => false, :unique => true
      string         :type, :null => false
      foreign_key   :object_id, :objects, :null => true
      text          :additional_info

      time          :created_at, :null => false
      time          :last_updated_at, :null => false
    end

    create_table :members do
      primary_key   :id
      foreign_key   :group_id, :subjects
      foreign_key   :user_id, :subjects

      time          :created_at, :null => false
      time          :last_updated_at, :null => false
    end

  end

  down do
    drop_table    :members
    drop_table    :subjects
    drop_table    :access_control_entries
    drop_table    :object_permission_set_map
    drop_table    :permissions
    drop_table    :objects
    drop_table    :permission_sets

  end
end
