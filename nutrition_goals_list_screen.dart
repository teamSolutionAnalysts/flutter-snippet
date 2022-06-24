import 'package:baseproject/src/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../apis/api_manager.dart';
import '../../../apis/error_model.dart';
import '../../../database/database_helper.dart';
import '../../../utils/constants/constants.dart';
import '../../../utils/constants/constants_color.dart';
import '../../../utils/constants/constants_fontsize.dart';
import '../../../utils/data_utils.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/localization/localization.dart';
import '../../../utils/navigation.dart';
import '../../../utils/progress_dialog.dart';
import '../../../widgets/add_custom_button.dart';
import '../../../widgets/custom_slidable_action.dart';
import '../../../widgets/goal_option.dart';
import '../../../widgets/toggle_bar.dart';
import '../add_custom_goal.dart';
import '../complete_goal.dart';
import '../model/goal_list_item.dart';
import '../model/predefine_goal_list_response_model.dart';

class NutritionGoalsListScreen extends StatefulWidget {
  @override
  _NutritionGoalsListScreenState createState() =>
      _NutritionGoalsListScreenState();
}

class _NutritionGoalsListScreenState extends State<NutritionGoalsListScreen> {
  DatabaseHelper dbHelper = DatabaseHelper.instance;

  List<GoalListItem> customGoalList = [];

  List<PredefineGoalData> predefinedGoalList = [];

  int currentPage;

  final GlobalKey<ToggleBarState> _myKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    currentPage = 0;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      getData();
    });
  }

  // fetching goal data from server API
  void getData() async {
    ProgressDialogUtils.showProgressDialog(context);
    ApiManager().nutritionGoalList().then((value) async {
      var tempList = value.data;
      for (var i = 0; i < value.data.length; i++) {
        var data = await dbHelper.getPredefineGoalItem(value.data[i].id);
        if (data.isEmpty) {
          var row = <String, dynamic>{
            DatabaseHelper.columnPredefineId: value.data[i].id,
            DatabaseHelper.columnDayCount: 0,
          };
          await dbHelper.insertPredefinedGoal(row);
          tempList[i].isSelected = false;
        } else {
          tempList[i].isSelected =
              await dbHelper.isPredefineGoalCompletedToday(tempList[i].id);
        }
      }
      setState(() {
        predefinedGoalList.addAll(tempList);
      });
      ProgressDialogUtils.dismissProgressDialog();
    }).catchError((dynamic e) {
      ProgressDialogUtils.dismissProgressDialog();
      if (e is ErrorModel) {
        showAlertDialog(context, e.error, statusCode: e.statusCode);
      } else {
        showAlertDialog(context, e.error);
      }
    });
    _getCustomGoalList();
  }

  // fetching data from local db for custom goals
  void _getCustomGoalList() async {
    final rows = await dbHelper.queryAllCustomGoalRows(nutritionGoalType);
    customGoalList.clear();
    rows.asMap().forEach((i, value) async {
      var isSelected = await DatabaseHelper.instance
          .isCustomGoalCompletedToday(value[DatabaseHelper.columnId] as int);
      setState(() {
        customGoalList.add(GoalListItem(
          value[DatabaseHelper.columnId] as int,
          value[DatabaseHelper.columnGoal],
          isSelected,
        ));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    var localization = Localization.of(context);

    //close complete goal bottom sheet
    void _closeSheet(int index, bool isSelected, bool isCustomGoal) {
      if (isCustomGoal) {
        _getCustomGoalList();
      } else {
        setState(() {
          predefinedGoalList[index].isSelected = isSelected;
        });
      }
      Navigator.pop(context);
    }

    // close add goal bottom sheet
    void _closeSheetAddGoal(bool redirectToCustom) {
      _getCustomGoalList();
      if (redirectToCustom && currentPage != 1) {
        setState(() {
          currentPage = 1;
          _myKey.currentState.updateSelection(1);
        });
      }
      Navigator.pop(context);
    }

    // open bottom sheet for completing a goal
    void _completeGoalBottomSheet(
        GoalListItem goalItem, int index, bool isGoalCompleted,
        {bool isCustomGoal}) {
      showModalBottomSheet(
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size15),
        ),
        backgroundColor: Colors.white,
        context: context,
        builder: (_) {
          return GestureDetector(
            onTap: () {},
            child: Wrap(children: [
              CompleteGoal(
                goalItem,
                _closeSheet,
                isGoalCompleted,
                isCustomGoal: isCustomGoal,
                index: index,
              ),
            ]),
            behavior: HitTestBehavior.opaque,
          );
        },
      );
    }

    Widget _getTitleText() => Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(left: size20, top: size20, bottom: size30),
            child: Text(
              localization.nutritionGoals,
              style: TextStyle(
                color: darkPrimaryTextColor,
                fontWeight: FontWeight.bold,
                fontSize: titleFontSize,
              ),
            ),
          ),
        );

    Widget _getTitleImage() => Padding(
          padding: EdgeInsets.only(
            left: size20,
            right: size20,
            top: size10,
          ),
          child: Image.asset(icNutritionTitle),
        );

    Widget _getTabs() => Padding(
          padding: EdgeInsets.symmetric(vertical: size10, horizontal: size15),
          child: ToggleBar(
            key: _myKey,
            totalHorizontalMargin: size30,
            labels: [
              Localization.of(context).nutritionGoals,
              Localization.of(context).customGoals,
            ],
            backgroundColor: Colors.white,
            selectedTabColor: secondaryColor,
            backgroundBorder: Border.all(color: inactiveBorderColor),
            borderRadius: size30,
            selectedTextColor: Colors.white,
            textColor: primaryTextColor,
            labelTextStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: titleFontSize,
            ),
            onSelectionUpdated: (index) => setState(() => currentPage = index),
          ),
        );

    Widget _getSubTitleText() => Container(
          padding: EdgeInsets.only(
            left: size20,
            right: size20,
            top: size10,
            bottom: size10,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              localization.addAndCompleteGoals,
              style: TextStyle(
                color: darkPrimaryTextColor,
                fontWeight: FontWeight.bold,
                fontSize: smallSubTitleFontSize,
              ),
            ),
          ),
        );

    Widget _getOptionPredefine(PredefineGoalData goalItem, int optionIndex) =>
        Container(
          padding: EdgeInsets.only(
            left: size20,
            right: size20,
            top: size10,
          ),
          child: GestureDetector(
            onTap: () {
              _completeGoalBottomSheet(
                GoalListItem(
                  goalItem.id,
                  goalItem.title,
                  goalItem.isSelected,
                ),
                optionIndex,
                goalItem.isSelected,
                isCustomGoal: false,
              );
            },
            child: GoalOption(
              goalItem.title,
              goalItem.isSelected,
            ),
          ),
        );

    Widget _getOptionCustom(GoalListItem goalItem, int optionIndex) =>
        Container(
          padding: EdgeInsets.only(
            left: size20,
            right: size20,
            top: size10,
          ),
          child: Slidable(
            key: const ValueKey(0),
            // The end action pane is the one at the right or the bottom side.
            endActionPane: ActionPane(
              extentRatio: 0.15,
              motion: ScrollMotion(),
              children: [
                MySlidableAction(
                  onPressed: (_) => _deleteCustomGoal(optionIndex),
                  backgroundColor: deleteBackgroundColor,
                  foregroundColor: Colors.white,
                  icon: Image.asset(
                    icDelete,
                    height: size30,
                    width: size30,
                  ),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () {
                _completeGoalBottomSheet(
                    goalItem, optionIndex, goalItem.isSelected,
                    isCustomGoal: true);
              },
              child: GoalOption(
                goalItem.myGoal,
                goalItem.isSelected,
              ),
            ),
          ),
        );

    Widget _getPreDefinedList() => Padding(
          padding: EdgeInsets.only(bottom: size30),
          child: ListView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemBuilder: (ctx, index) {
              return _getOptionPredefine(predefinedGoalList[index], index);
            },
            itemCount: predefinedGoalList.length,
          ),
        );

    Widget _getCustomList() => customGoalList.isNotEmpty
        ? ListView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemBuilder: (ctx, index) {
              return _getOptionCustom(customGoalList[index], index);
            },
            itemCount: customGoalList.length,
          )
        : Container(
            margin: EdgeInsets.all(size10),
            height: size150,
            child: Center(
                child: Text(
              localization.noCustomGoal,
              style: TextStyle(
                color: Colors.black,
                fontSize: subTitleFontSize,
                fontWeight: FontWeight.bold,
              ),
            )),
          );

    Widget _getPages() =>
        currentPage == 0 ? _getPreDefinedList() : _getCustomList();

    // open bottom sheet for adding a goal
    void _addGoalClicked() {
      showModalBottomSheet(
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size15),
        ),
        backgroundColor: Colors.white,
        context: context,
        builder: (_) {
          return Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: GestureDetector(
              onTap: () {},
              child: Wrap(children: [
                AddCustomGoal(_closeSheetAddGoal, nutritionGoalType)
              ]),
              behavior: HitTestBehavior.opaque,
            ),
          );
        },
      );
    }

    Widget _getAddGoalButton() => Visibility(
          visible: currentPage == 1,
          child: Padding(
            padding: EdgeInsets.only(
              left: size20,
              right: size20,
              top: size30,
              bottom: size30,
            ),
            child: AddCustomButton(localization.addCustomGoal, _addGoalClicked),
          ),
        );

    void _backPressed() {
      Navigator.of(context).pop();
    }

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: primaryColor,
          title: Container(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Image.asset(
                    icLeftArrowWhite,
                    height: size50,
                    width: size50,
                  ),
                  onPressed: _backPressed,
                ),
                Image.asset(
                  icKenaOnly,
                  height: size50,
                  width: size50,
                ),
                Center(
                  child: GestureDetector(
                    onTap: () =>
                        NavigationUtils.push(context, routeNotifications),
                    child: Container(
                      padding: EdgeInsets.all(size10),
                      height: size50,
                      width: size50,
                      child: Stack(
                        children: [
                          Image.asset(icNotification),
                          Align(
                            alignment: Alignment.topRight,
                            child: Image.asset(icNotiDot),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Container(
          color: primaryColor,
          child: ClipRRect(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(size15),
                topRight: Radius.circular(size15)),
            child: Container(
              color: Colors.white,
              child: SizedBox.expand(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _getTitleText(),
                      _getTitleImage(),
                      _getTabs(),
                      _getSubTitleText(),
                      _getPages(),
                      _getAddGoalButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // delete custom goal from local db
  void _deleteCustomGoal(int index) async {
    showOkCancelAlertDialog(
      context: context,
      message: Localization.of(context).deleteGoalConfirmText,
      cancelButtonTitle: Localization.of(context).cancel,
      okButtonTitle: Localization.of(context).yes,
      okButtonAction: () async {
        await dbHelper.deleteCustomGoal(customGoalList[index].id);
        showToast(Localization.of(context).goalDeleteMsg);
        setState(() {
          customGoalList.removeAt(index);
        });
      },
    );
  }
}
