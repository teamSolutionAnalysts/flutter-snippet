import 'dart:developer';

import 'package:baseproject/src/apis/api_manager.dart';
import 'package:baseproject/src/apis/error_model.dart';
import 'package:baseproject/src/ui/home/model/update_profile_point_request_model.dart';
import 'package:baseproject/src/utils/constants/constants.dart';
import 'package:baseproject/src/utils/dialog_utils.dart';
import 'package:baseproject/src/utils/preference_utils.dart';
import 'package:baseproject/src/utils/progress_dialog.dart';
import 'package:baseproject/src/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final _databaseName = "KENADatabase.db";
  static final _databaseVersion = 1;

  static final customGoalTable = 'custom_goal_table';
  static final predefineGoalTable = 'predefine_goal_table';
  static final goalDatesTable = 'goal_dates_table';

  static final columnId = '_id';
  static final columnGoal = 'goal';
  static final columnGoalType = 'goal_type';
  static final columnGoalDate = 'goal_date';
  static final columnSavedDate = 'saved_date';
  static final columnDayCount = 'day_count';

  static final columnPredefineId = 'predefine_id';
  static final columnGoalId = 'goal_id';

  // make this a singleton class
  DatabaseHelper._privateConstructor();

  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  // only have a single app-wide reference to the database
  static Database _database;

  Future<Database> get database async {
    if (_database != null) return _database;
    // lazily instantiate the db the first time it is accessed
    _database = await _initDatabase();
    return _database;
  }

  // this opens the database (and creates it if it doesn't exist)
  _initDatabase() async {
    var documentsDirectory = await getApplicationDocumentsDirectory();
    var path = join(documentsDirectory.path, _databaseName);
    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate);
  }

  // SQL code to create the database table
  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $customGoalTable (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnGoal TEXT NOT NULL,
            $columnGoalType INTEGER NOT NULL,
            $columnDayCount INTEGER NOT NULL
          )
          ''');
    await db.execute('''
          CREATE TABLE $predefineGoalTable (
            $columnId INTEGER PRIMARY KEY,
            $columnPredefineId INTEGER NOT NULL,
            $columnDayCount INTEGER NOT NULL
          )
          ''');
    await db.execute('''
          CREATE TABLE $goalDatesTable (
            $columnId INTEGER PRIMARY KEY,
            $columnGoalId INTEGER NOT NULL,
            $columnGoalType INTEGER NOT NULL,
            $columnSavedDate DATETIME NOT NULL
          )
          ''');
  }

  // Helper methods

  // Inserts a row in the database where each key in the Map is a column name
  // and the value is the column value. The return value is the id of the
  // inserted row.
  Future<int> insertCustomGoal(Map<String, dynamic> row) async {
    var db = await instance.database;
    return await db.insert(customGoalTable, row);
  }

  Future<List<Map<String, dynamic>>> getCustomGoalItem(int predefineId) async {
    var db = await instance.database;
    return await db.query(customGoalTable,
        where: '$columnId = ?', whereArgs: [predefineId], limit: 1);
  }

  Future<List<Map<String, dynamic>>> getPredefineGoalItem(
      int predefineId) async {
    var db = await instance.database;
    return await db.query(predefineGoalTable,
        where: '$columnPredefineId = ?', whereArgs: [predefineId], limit: 1);
  }

  Future<List<Map<String, dynamic>>> getGoalDateList(
      int goalId, String goalDate, int goalType) async {
    var db = await instance.database;
    return await db.query(goalDatesTable,
        where:
            '$columnGoalId = ? and $columnSavedDate = ? and $columnGoalType = ?',
        whereArgs: [goalId, goalDate, goalType]);
  }

  Future<List<Map<String, dynamic>>> getDateList() async {
    var db = await instance.database;
    return await db.query(goalDatesTable);
  }

  // Use this function before checking the existing data. We cannot afford to
  // have a duplicate entry
  Future<int> insertPredefinedGoal(Map<String, dynamic> row) async {
    var db = await instance.database;
    return await db.insert(predefineGoalTable, row);
  }

  // All of the rows are returned as a list of maps, where each map is
  // a key-value list of columns.
  Future<List<Map<String, dynamic>>> queryAllCustomGoalRows(
      int goalType) async {
    var db = await instance.database;
    return await db.query(customGoalTable,
        where: '$columnGoalType = ?', whereArgs: [goalType]);
  }

  // All of the methods (insert, query, update, delete) can also be done using
  // raw SQL commands. This method uses a raw query to give the row count.
  Future<int> queryCustomGoalRowCount() async {
    var db = await instance.database;
    return Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $customGoalTable'));
  }

  // We are assuming here that the id column in the map is set. The other
  // column values will be used to update the row.
  Future<int> updateCustomGoal(
      int goalId, bool isGoalAlreadyCompleted, BuildContext context) async {
    var db = await instance.database;
    var todayDate = DateFormat(localDBDateFormat).format(DateTime.now());
    var yesterdayDate = DateFormat(localDBDateFormat)
        .format(DateTime.now().subtract(Duration(days: 1)));
    var row = <String, dynamic>{
      columnGoalId: goalId,
      columnGoalType: customGoalType,
      columnSavedDate: todayDate.toString(),
    };
    await db.insert(goalDatesTable, row);
    var dateList =
        await getGoalDateList(goalId, yesterdayDate.toString(), customGoalType);
    var savedNumberOfDayGoal1 = await getInt(prefNumberOfDayGoal1);
    var savedNumberOfDayGoal2 = await getInt(prefNumberOfDayGoal2);

    var dayCount = 0;
    var data = await getPredefineGoalItem(goalId);
    if (data.isNotEmpty) {
      var goalItem = data[0];
      dayCount = goalItem[columnDayCount] as int;
      if (isGoalAlreadyCompleted) {
        // means we need to remove a day
        if (dayCount == savedNumberOfDayGoal1) {
          // call API for remove 10 days
          await _updatePoints(goal10RemovedPointsType, context);
        } else if (dayCount == savedNumberOfDayGoal2) {
          // call API for remove 30 days
          await _updatePoints(goal30RemovedPointsType, context);
        }
        dayCount--;
      } else {
        // means we need to add a day
        if (dateList.length % 2 == 0) {
          //goal not added yesterday
          dayCount = 1;
        } else {
          //goal added yesterday
          if (dayCount == savedNumberOfDayGoal2) {
            dayCount = 1;
          } else {
            dayCount++;
          }
          if (dayCount == savedNumberOfDayGoal1) {
            // call API for 10 days
            await _updatePoints(goal10UpdatedPointsType, context);
          } else if (dayCount == savedNumberOfDayGoal2) {
            // call API for 30 days
            await _updatePoints(goal30UpdatedPointsType, context);
          }
        }
      }
    }
    return await db.rawUpdate('''
    UPDATE ${DatabaseHelper.customGoalTable}
    SET ${DatabaseHelper.columnDayCount} = ?
    WHERE ${DatabaseHelper.columnId} = ?
    ''', [dayCount, goalId]);
  }

  Future<bool> updatePredefineGoal(
      int goalId, bool isGoalAlreadyCompleted, BuildContext context) async {
    var db = await instance.database;
    var todayDate = DateFormat(localDBDateFormat).format(DateTime.now());
    var yesterdayDate = DateFormat(localDBDateFormat)
        .format(DateTime.now().subtract(Duration(days: 1)));
    var row = <String, dynamic>{
      columnGoalId: goalId,
      columnGoalType: predefineGoalType,
      columnSavedDate: todayDate.toString(),
    };
    await db.insert(goalDatesTable, row);

    var dateList = await getGoalDateList(
        goalId, yesterdayDate.toString(), predefineGoalType);
    var savedNumberOfDayGoal1 = await getInt(prefNumberOfDayGoal1);
    var savedNumberOfDayGoal2 = await getInt(prefNumberOfDayGoal2);

    var dayCount = 0;
    var data = await getPredefineGoalItem(goalId);
    if (data.isNotEmpty) {
      var goalItem = data[0];
      dayCount = goalItem[columnDayCount] as int;
      if (isGoalAlreadyCompleted) {
        // means we need to remove a day
        if (dayCount == savedNumberOfDayGoal1) {
          // call API for remove 10 days
          await _updatePoints(goal10RemovedPointsType, context);
        } else if (dayCount == savedNumberOfDayGoal2) {
          // call API for remove 30 days
          await _updatePoints(goal30RemovedPointsType, context);
        }
        dayCount--;
      } else {
        // means we need to add a day
        if (dateList.length % 2 == 0) {
          //goal not added yesterday
          dayCount = 1;
        } else {
          //goal added yesterday
          if (dayCount == savedNumberOfDayGoal2) {
            dayCount = 1;
          } else {
            dayCount++;
          }
          if (dayCount == savedNumberOfDayGoal1) {
            // call API for 10 days
            await _updatePoints(goal10UpdatedPointsType, context);
          } else if (dayCount == savedNumberOfDayGoal2) {
            // call API for 30 days
            await _updatePoints(goal30UpdatedPointsType, context);
          }
        }
      }
    }
    await db.rawUpdate('''
    UPDATE ${DatabaseHelper.predefineGoalTable}
    SET ${DatabaseHelper.columnDayCount} = ?
    WHERE ${DatabaseHelper.columnPredefineId} = ?
    ''', [dayCount, goalId]);
    return !isGoalAlreadyCompleted;
  }

  Future<bool> isPredefineGoalCompletedToday(int goalId) async {
    var dateList = await getGoalDateList(
        goalId,
        DateFormat(localDBDateFormat).format(DateTime.now()).toString(),
        predefineGoalType);
    if (dateList.length % 2 == 0) {
      return false;
    } else {
      return true;
    }
  }

  Future<bool> isCustomGoalCompletedToday(int goalId) async {
    var dateList = await getGoalDateList(
        goalId,
        DateFormat(localDBDateFormat).format(DateTime.now()).toString(),
        customGoalType);
    if (dateList.length % 2 == 0) {
      return false;
    } else {
      return true;
    }
  }

  // Deletes the row specified by the id. The number of affected rows is
  // returned. This should be 1 as long as the row exists.
  Future<int> deleteCustomGoal(int goalId) async {
    var db = await instance.database;
    return await db
        .delete(customGoalTable, where: '$columnId = ?', whereArgs: [goalId]);
  }

  Future<void> deleteDB() async {
    final db = await instance.database;
    db.delete(customGoalTable);
    db.delete(predefineGoalTable);
    db.delete(goalDatesTable);
  }

  Future<bool> _updatePoints(int pointType, BuildContext context) async {

    ProgressDialogUtils.showProgressDialog(context);
    var result = await ApiManager()
        .updatePoints(
            UpdatePointsRequestModel(pointsType: pointType.toString()))
        .then((value) async {
      await setInt(prefDailyCount, 0);
      await setString(prefUpdatingDate, '');
      await setString(prefLastUpdatedDate, '');
      showToast(value.message);
      ProgressDialogUtils.dismissProgressDialog();
      return true;
    }).catchError((dynamic e) {
      ProgressDialogUtils.dismissProgressDialog();
      if (e is ErrorModel) {
        showAlertDialog(context, e.error, statusCode: e.statusCode);
      } else {
        showAlertDialog(context, e.error);
      }
      return false;
    });
    return result;
  }
}
