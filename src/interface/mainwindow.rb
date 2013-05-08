# coding: UTF-8
#~~~~~~~~~~~~~~~~~~~~~~~~~~
# Copyright (C) 2013 Vladislav Mileshkin
#
# This file is part of TMIS.
#
# TMIS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# TMIS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with TMIS. If not, see <http://www.gnu.org/licenses/>.
#~~~~~~~~~~~~~~~~~~~~~~~~~~
require 'Qt'
require 'mail'
require 'tmpdir'
require 'fileutils'
require 'contracts'
#~~~~~~~~~~~~~~~~~~~~~~~~~~
require './src/engine/database'
require './src/engine/import/timetable_manager'
require './src/engine/import/timetable_reader'
require './src/engine/import/spreadsheet_roo'
require './src/engine/export/timetable_exporter.rb'
require './src/engine/mailer/mailer'
require './src/interface/ui_mainwindow'
require './src/interface/forms/settings'
require './src/engine/models/cabinet'
require './src/engine/models/course'
require './src/engine/models/group'
require './src/engine/models/lecturer'
require './src/engine/models/semester'
require './src/engine/models/speciality'
require './src/engine/models/speciality_subject'
require './src/engine/models/study'
require './src/engine/models/subject'
require './src/engine/models/subgroup'
require './src/interface/models/cabinet_table_model'
require './src/interface/models/course_table_model'
require './src/interface/models/group_table_model'
require './src/interface/models/lecturer_table_model'
require './src/interface/models/semester_table_model'
require './src/interface/models/speciality_table_model'
require './src/interface/models/speciality_subject_table_model'
require './src/interface/models/study_table_model'
require './src/interface/models/subject_table_model'
require './src/interface/models/subgroup_table_model'
#~~~~~~~~~~~~~~~~~~~~~~~~~~
class MainWindow < Qt::MainWindow

  # File menu
  slots 'on_newAction_triggered()'
  slots 'on_openAction_triggered()'
  slots 'on_saveAction_triggered()'
  slots 'on_saveAsAction_triggered()'
  slots 'on_importAction_triggered()'
  slots 'on_exportAction_triggered()'
  slots 'on_closeAction_triggered()'
  slots 'on_quitAction_triggered()'
  # Tools menu
  slots 'on_settingsAction_triggered()'
  # Self
  slots 'open_file()'
  slots 'clear_recent_files()'

  def initialize(parent = nil)
    super(parent)
    @ui = Ui::MainWindow.new
    @ui.setup_ui(self)
    @tables_views = [@ui.cabinetsTableView, @ui.coursesTableView, @ui.groupsTableView, @ui.lecturersTableView, @ui.semestersTableView,
                     @ui.specialitySubjectsTableView, @ui.specialitiesTableView, @ui.studiesTableView, @ui.subgroupsTableView, @ui.subjectsTableView]
    @tables_views.each{ |x| x.visible = false }
    @temp = ->(){ "#{Dir.mktmpdir('tmis')}/temp.sqlite" }
    @clear_recent_action = Qt::Action.new('Очистить', self)
    @clear_recent_action.setData(Qt::Variant.new('clear'))
    connect(@clear_recent_action, SIGNAL('triggered()'), self, SLOT('clear_recent_files()'))
    @ui.recentMenu.clear
    @ui.recentMenu.addActions([@clear_recent_action] + Settings[:recent, :files].split.map{ |path| create_recent_action(path) })
  end

  def on_newAction_triggered
    Database.instance.connect_to(@temp.())
    show_tables
  end

  def on_openAction_triggered
    if (filename = Qt::FileDialog::getOpenFileName(self, 'Open File', '', 'TMIS databases (SQLite3)(*.sqlite)'))
      Database.instance.connect_to(filename)
      update_recent(filename)
      show_tables
    end
  end

  def on_saveAction_triggered
  end

  def on_saveAsAction_triggered
    if (filename = Qt::FileDialog::getSaveFileName(self, 'Save File', 'NewTimetable.sqlite', 'TMIS databases (SQLite3)(*.sqlite)'))
      FileUtils.cp(Database.instance.path, filename) unless Database.instance.path == filename
      Database.instance.connect_to(filename)
      update_recent(filename)
      show_tables
    end
  end

  def on_importAction_triggered
    please_wait do
      if (filename = Qt::FileDialog::getOpenFileName(self, 'Open File', '', 'Spreadsheets(*.xls *.xlsx *.ods *.csv)'))
        sheet = SpreadsheetCreater.create(filename)
        reader = TimetableReader.new(sheet, :first!)
        Database.instance.connect_to(@temp.())
        TimetableManager.new(reader).save_to_db
        show_tables
      end
    end
  end

  def on_exportAction_triggered
    timetable_for_lecturer(Lecturer.find(1))
  end

  def on_closeAction_triggered
    @tables_views.each{ |x| x.hide }
    #@db.disconnect
  end

  def on_quitAction_triggered
    on_closeAction_triggered
    recent = @ui.recentMenu.actions
    Settings[:recent, :files] = recent[1..recent.size-1].map{ |a| a.data.value.to_s }.join(' ')
    puts 'Sayonara!'
    Qt::Application.quit
  end

  def on_settingsAction_triggered
    SettingsDialog.new.exec
  end

  def timetable_for_lecturer(lecturer)
    text = "Здравствуйте, #{lecturer.to_s}! Ваши пары на этой неделе:\n\n"
    grouped = lecturer.studies.group(:date, :number).group_by(&:date)
    grouped.each do |date, studies|
      text += "Дата: #{date}\n\n"
      studies.each do |s|
        text += "\t Номер: #{s.number}, группа: #{s.groupable.title}, предмет #{s.subject.title}, кабинет: #{s.cabinet.title}\n"
      end
    end
    text += "\nИтого пар: #{lecturer.studies.count}\n"

    spreadsheet = SpreadsheetCreater.create('Timetable.xls')
    LecturerWeekTimetableExporter.new(lecturer, spreadsheet).export.save
    Mailer.new(Settings[:mailer, :email], Settings[:mailer, :password]) do
      from    'tmis@kp11.ru'
      to      'noein93@gmail.com'
      subject 'Расписание'
      body     text
      add_file :filename => 'timetable.xls', :content => File.read('Timetable.xls')
    end.send!
    File.delete('Timetable.xls')
  end

  def show_tables
    # Переменные экземпляра используются для обхода бага:
    # http://stackoverflow.com/questions/9715548/cant-display-more-than-one-table-model-inheriting-from-the-same-class-on-differ
    tables = { Cabinet: :cabinets, Course: :courses, Group: :groups, Lecturer: :lecturers, Semester: :semesters,
               Speciality: :specialities, SpecialitySubject: :specialitySubjects, Study: :studies, Subgroup: :subgroups, Subject: :subjects }
    tables.each_pair do |model, entities|
      eval("@#{model.downcase}_model = #{model}TableModel.new(#{model}.all)\n\
            @ui.#{entities}TableView.model = @#{model.downcase}_model\n\
            @ui.#{entities}TableView.horizontalHeader.setResizeMode(Qt::HeaderView::Stretch)\n\
            @ui.#{entities}TableView.show")
    end
  end

  def open_file
    filename = sender.data.value.to_s
    if File.exist? filename
      Database.instance.connect_to(filename)
      update_recent(filename)
      show_tables
    end
  end

  Contract String => Qt::Action
  def create_recent_action(path)
    action = Qt::Action.new(path[path.size-10..path.size], self)
    connect(action, SIGNAL('triggered()'), self, SLOT('open_file()'))
    action.setData(Qt::Variant.new(path)); action
  end

  Contract String => Any
  def update_recent(filename)
    actions = @ui.recentMenu.actions
    if actions.size > 5
      @ui.recentMenu.clear
      @ui.recentMenu.addActions([@clear_recent_action] + actions[1..actions.size-1])
    else
      @ui.recentMenu.addAction(create_recent_action(filename))
    end
  end

  def clear_recent_files
    @ui.recentMenu.clear
    @ui.recentMenu.addAction(@clear_recent_action)
  end

  def please_wait(&block)
    @ui.statusbar.showMessage('Please, wait...')
    yield block
    @ui.statusbar.clearMessage
  end

end
