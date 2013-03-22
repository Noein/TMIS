class AddIndexes < ActiveRecord::Migration
  def change
    add_index(:groups, :title)
    add_index(:subgroups, :group_id)
    add_index(:subgroups, :number)
    add_index(:subjects, :title)
    add_index(:cabinets, :title)
    add_index(:lecturers, :surname)
    add_index(:studies, :subject_id)
    add_index(:studies, :lecturer_id)
    add_index(:studies, :cabinet_id)
    add_index(:studies, [:groupable_id, :groupable_type])
    add_index(:courses, :number)
    add_index(:specialities, :title)
    add_index(:semesters, :course_id)
    add_index(:semesters, :title)
    add_index(:speciality_subjects, :subject_id)
    add_index(:speciality_subjects, :semester_id)
  end
end
