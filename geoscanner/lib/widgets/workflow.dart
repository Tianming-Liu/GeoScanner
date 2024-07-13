import 'package:flutter/material.dart';
import 'package:timelines/timelines.dart';
import 'package:google_fonts/google_fonts.dart';

class Workflow extends StatefulWidget {
  const Workflow({super.key, required this.initialSteps, this.onStepCompleted});
  final List<WorkflowStep> initialSteps;
  final Function(int stepIndex, [int? subStepIndex])? onStepCompleted;

  @override
  State<Workflow> createState() => _WorkflowState();
}

class _WorkflowState extends State<Workflow> {
  late List<WorkflowStep> _workflowSteps;

  @override
  void initState() {
    super.initState();
    _workflowSteps = widget.initialSteps;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: FixedTimeline.tileBuilder(
        theme: TimelineThemeData(
          nodePosition: 0,
          color: const Color(0xff989898),
          indicatorTheme: const IndicatorThemeData(
            position: 0,
            size: 17.5,
          ),
          connectorTheme: const ConnectorThemeData(
            thickness: 2.5,
          ),
        ),
        builder: TimelineTileBuilder.connected(
          connectionDirection: ConnectionDirection.before,
          itemCount: _workflowSteps.length,
          contentsBuilder: (_, index) {
            final step = _workflowSteps[index];
            return Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (step.subSteps.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.only(
                        left: 15.0,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey, width: 0.2),
                        borderRadius: BorderRadius.circular(5),
                        color: step.isError
                            ? Colors.red.shade50
                            : Colors.grey.shade50,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            step.icon,
                            color: step.isError
                                ? Colors.red
                                : step.isCompleted
                                    ? Colors.green
                                    : const Color.fromARGB(255, 100, 100, 100),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 25.0),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  step.title,
                                  style: TextStyle(
                                    fontFamily: GoogleFonts.roboto().fontFamily,
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w400,
                                    color: step.isError
                                        ? Colors.red
                                        : step.isCompleted
                                            ? Colors.green
                                            : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.only(left: 15.0),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey, width: 0.2),
                        borderRadius: BorderRadius.circular(5),
                        color: step.isError
                            ? Colors.red.shade50
                            : Colors.grey.shade50,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            step.icon,
                            color: step.isError
                                ? Colors.red
                                : step.isCompleted
                                    ? Colors.green
                                    : const Color.fromARGB(255, 100, 100, 100),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 25.0),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  step.title,
                                  style: TextStyle(
                                    fontFamily: GoogleFonts.roboto().fontFamily,
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w400,
                                    color: step.isError
                                        ? Colors.red
                                        : step.isCompleted
                                            ? Colors.green
                                            : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: _InnerTimeline(
                        stepIndex: index,
                        subSteps: step.subSteps,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          indicatorBuilder: (context, index) {
            final step = _workflowSteps[index];
            return OutlinedDotIndicator(
              color: step.isError
                  ? Colors.red
                  : step.isCompleted
                      ? const Color(0xff6ad192)
                      : const Color(0xffe6e7e9),
              backgroundColor: step.isError
                  ? Colors.red.shade50
                  : step.isCompleted
                      ? const Color(0xffd4f5d6)
                      : const Color(0xffc2c5c9),
              borderWidth: step.isError
                  ? 3.0
                  : step.isCompleted
                      ? 3.0
                      : 2.5,
            );
          },
          connectorBuilder: (context, index, connectorType) {
            Color? color;
            if (index + 1 < _workflowSteps.length - 1 &&
                _workflowSteps[index].isCompleted &&
                _workflowSteps[index + 1].isCompleted) {
              color = _workflowSteps[index].isCompleted
                  ? const Color(0xff6ad192)
                  : null;
            }
            return SolidLineConnector(
              color: color,
            );
          },
        ),
      ),
    );
  }
}

class _InnerTimeline extends StatelessWidget {
  const _InnerTimeline({
    required this.stepIndex,
    required this.subSteps,
  });

  final int stepIndex;
  final List<WorkflowSubStep> subSteps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: FixedTimeline.tileBuilder(
        theme: TimelineThemeData(
          nodePosition: 0,
          color: const Color(0xff989898),
          indicatorTheme: const IndicatorThemeData(
            position: 0,
            size: 15.0,
          ),
          connectorTheme: const ConnectorThemeData(
            thickness: 2.5,
          ),
        ),
        builder: TimelineTileBuilder.connected(
          connectionDirection: ConnectionDirection.before,
          itemCount: subSteps.length,
          contentsBuilder: (_, index) {
            final subStep = subSteps[index];
            return Padding(
              padding: EdgeInsets.only(
                left: 16.0,
                bottom:
                    index == subSteps.length - 1 ? 0.0 : 18.0, // 最后一个子节点不添加底部间距
              ),
              child: Container(
                padding: const EdgeInsets.only(left: 15.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey, width: 0.2),
                  borderRadius: BorderRadius.circular(5),
                  color: subStep.isError
                      ? Colors.red.shade50
                      : Colors.grey.shade50,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      subStep.icon,
                      color: subStep.isError
                          ? Colors.red
                          : subStep.isCompleted
                              ? Colors.green
                              : const Color.fromARGB(255, 100, 100, 100),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 25.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            subStep.title,
                            style: TextStyle(
                              fontFamily: GoogleFonts.roboto().fontFamily,
                              fontSize: 16.0,
                              fontWeight: FontWeight.normal,
                              color: subStep.isError
                                  ? Colors.red
                                  : subStep.isCompleted
                                      ? Colors.green
                                      : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          indicatorBuilder: (context, index) {
            final subStep = subSteps[index];
            return OutlinedDotIndicator(
              color: subStep.isError
                  ? Colors.red
                  : subStep.isCompleted
                      ? const Color(0xff6ad192)
                      : const Color(0xffe6e7e9),
              backgroundColor: subStep.isError
                  ? Colors.red.shade50
                  : subStep.isCompleted
                      ? const Color(0xffd4f5d6)
                      : const Color(0xffc2c5c9),
              borderWidth: subStep.isError
                  ? 3.0
                  : subStep.isCompleted
                      ? 3.0
                      : 2.5,
            );
          },
          connectorBuilder: (context, index, connectorType) {
            Color? color;
            if (index + 1 < subSteps.length &&
                subSteps[index].isCompleted &&
                subSteps[index + 1].isCompleted) {
              color =
                  subSteps[index].isCompleted ? const Color(0xff6ad192) : null;
            }
            return SolidLineConnector(
              color: color,
            );
          },
        ),
      ),
    );
  }
}

class WorkflowStep {
  final String title;
  final List<WorkflowSubStep> subSteps;
  final IconData icon;
  bool isCompleted;
  bool isError;

  WorkflowStep(this.title,
      {this.subSteps = const [],
      this.icon = Icons.circle,
      this.isCompleted = false,
      this.isError = false});
}

class WorkflowSubStep {
  final String title;
  final IconData icon;
  bool isCompleted;
  bool isError;

  WorkflowSubStep(this.title,
      {this.icon = Icons.circle,
      this.isCompleted = false,
      this.isError = false});
}
