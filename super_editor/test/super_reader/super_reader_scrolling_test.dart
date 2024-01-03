import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_runners/flutter_test_runners.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_reader_test.dart';

import '../test_tools.dart';
import 'reader_test_tools.dart';
import 'test_documents.dart';

void main() {
  group("SuperReader scrolling", () {
    testWidgetsOnArbitraryDesktop('scrolls document when dragging using the trackpad (downstream)', (tester) async {
      final scrollController = ScrollController();
      await tester
          .createDocument() //
          .withLongTextContent()
          .withEditorSize(const Size(300, 300))
          .withScrollController(scrollController)
          .pump();

      final document = SuperReaderInspector.findDocument()!;
      final firstParagraph = document.nodes.first as ParagraphNode;

      final dragGesture = await tester.startDocumentDragFromPosition(
        from: DocumentPosition(
          nodeId: firstParagraph.id,
          nodePosition: firstParagraph.beginningPosition,
        ),
        startAlignmentWithinPosition: Alignment.topLeft,
        deviceKind: PointerDeviceKind.trackpad,
      );

      // Move a distance big enough to ensure a pan gesture.
      await dragGesture.moveBy(const Offset(0, kPanSlop));
      await tester.pump();

      // Drag up.
      await dragGesture.moveBy(const Offset(0, -300));
      await tester.pump();

      await tester.endDocumentDragGesture(dragGesture);

      // Ensure the document scrolled down.
      expect(scrollController.offset, greaterThan(0));
    });

    testWidgetsOnArbitraryDesktop('scrolls document when dragging using the trackpad (upstream)', (tester) async {
      final scrollController = ScrollController();
      await tester
          .createDocument() //
          .withLongTextContent()
          .withEditorSize(const Size(300, 300))
          .withScrollController(scrollController)
          .pump();

      final document = SuperReaderInspector.findDocument()!;
      final lastParagraph = document.nodes.last as ParagraphNode;

      // Jump to the end of the document
      scrollController.jumpTo(scrollController.position.maxScrollExtent);

      final dragGesture = await tester.startDocumentDragFromPosition(
        from: DocumentPosition(
          nodeId: lastParagraph.id,
          nodePosition: lastParagraph.endPosition,
        ),
        startAlignmentWithinPosition: Alignment.bottomRight,
        deviceKind: PointerDeviceKind.trackpad,
      );

      // Move a distance big enough to ensure a pan gesture.
      await dragGesture.moveBy(const Offset(0, kPanSlop));
      await tester.pump();

      // Drag down.
      await dragGesture.moveBy(const Offset(0, 300));
      await tester.pump();

      await tester.endDocumentDragGesture(dragGesture);

      // Ensure the document scrolled up.
      expect(scrollController.offset, lessThan(scrollController.position.maxScrollExtent));
    });

    testWidgetsOnDesktop("auto-scrolls down", (tester) async {
      const windowSize = Size(800, 600);
      tester.view.physicalSize = windowSize;

      await tester //
          .createDocument() //
          .withLongTextContent() //
          .forDesktop() //
          .pump();

      final document = SuperReaderInspector.findDocument()!;
      final firstParagraph = document.nodes.first as ParagraphNode;
      final lastParagraph = document.nodes.last as ParagraphNode;

      final dragGesture = await tester.startDocumentDragFromPosition(
        from: DocumentPosition(
          nodeId: firstParagraph.id,
          nodePosition: firstParagraph.beginningPosition,
        ),
        startAlignmentWithinPosition: Alignment.topLeft,
      );
      await dragGesture.moveBy(Offset(windowSize.width - 20, windowSize.height - 20));
      // Pump enough times to scroll all the way to the top.
      // TODO: find a way to scroll as much as possible without pumping an arbitrary number of times
      for (int i = 0; i < 60; i += 1) {
        await tester.pump();
      }
      await tester.endDocumentDragGesture(dragGesture);

      // Ensure that the entire document is selected.
      expect(
        SuperReaderInspector.findDocumentSelection(),
        DocumentSelection(
          base: DocumentPosition(
            nodeId: firstParagraph.id,
            nodePosition: firstParagraph.beginningPosition,
          ),
          extent: DocumentPosition(
            nodeId: lastParagraph.id,
            nodePosition: lastParagraph.endPosition,
          ),
        ),
      );
    });

    testWidgetsOnDesktop("auto-scrolls up", (tester) async {
      const windowSize = Size(800, 600);
      tester.view.physicalSize = windowSize;

      final testDocContext = await tester //
          .createDocument() //
          .withLongTextContent() //
          .forDesktop() //
          .pump();

      final document = SuperReaderInspector.findDocument()!;
      final firstParagraph = document.nodes.first as ParagraphNode;
      final lastParagraph = document.nodes.last as ParagraphNode;

      // Place the caret at the end of the document, which causes the editor to
      // scroll to the bottom.
      testDocContext.documentContext.selection.value = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: lastParagraph.id,
          nodePosition: lastParagraph.endPosition,
        ),
      );
      testDocContext.focusNode.requestFocus();
      await tester.pumpAndSettle();

      final dragGesture = await tester.startDocumentDragFromPosition(
        from: DocumentPosition(
          nodeId: lastParagraph.id,
          nodePosition: lastParagraph.endPosition,
        ),
        startAlignmentWithinPosition: Alignment.bottomRight,
      );
      await dragGesture.moveBy(-Offset(windowSize.width - 20, windowSize.height - 20));
      // Pump enough times to scroll all the way to the top.
      // TODO: find a way to scroll as much as possible without pumping an arbitrary number of times
      for (int i = 0; i < 60; i += 1) {
        await tester.pump();
      }
      await tester.endDocumentDragGesture(dragGesture);

      // Ensure that the entire document is selected.
      expect(
        SuperReaderInspector.findDocumentSelection(),
        DocumentSelection(
          base: DocumentPosition(
            nodeId: lastParagraph.id,
            nodePosition: lastParagraph.endPosition.copyWith(affinity: TextAffinity.upstream),
          ),
          extent: DocumentPosition(
            nodeId: firstParagraph.id,
            nodePosition: firstParagraph.beginningPosition,
          ),
        ),
      );
    });

    testWidgetsOnDesktop("auto-scrolls to caret position", (tester) async {
      const windowSize = Size(800, 600);
      tester.view.physicalSize = windowSize;

      final docContext = await tester //
          .createDocument() //
          .withLongTextContent() //
          .forDesktop() //
          .pump();
      final document = SuperReaderInspector.findDocument()!;
      final lastParagraph = document.nodes.last as ParagraphNode;

      // Place the caret at the end of the document, which should cause the
      // editor to scroll to the bottom.
      docContext.documentContext.selection.value = DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: lastParagraph.id,
          nodePosition: lastParagraph.endPosition,
        ),
      );
      docContext.focusNode.requestFocus();
      await tester.pumpAndSettle();

      // Ensure that the last character in the document is visible.
      expect(
        SuperReaderInspector.isPositionVisibleGlobally(
          DocumentPosition(
            nodeId: lastParagraph.id,
            nodePosition: lastParagraph.endPosition,
          ),
          windowSize,
        ),
        isTrue,
      );
    });

    testWidgetsOnAndroid("doesn't overscroll when dragging down", (tester) async {
      final scrollController = ScrollController();

      await tester //
          .createDocument()
          .withSingleParagraph()
          .withScrollController(scrollController)
          .pump();

      // Ensure the reader didn't start scrolled.
      expect(scrollController.offset, 0);

      // Drag an arbitrary amount of pixels from the top of the reader.
      final dragGesture = await tester.dragByFrameCount(
        startLocation: tester.getRect(find.byType(SuperReader)).topCenter + const Offset(0, 5),
        totalDragOffset: const Offset(0, 200.0),
      );

      // Ensure we don't scroll.
      expect(scrollController.offset, 0);

      // End the gesture.
      await dragGesture.up();

      // Wait for the long-press timer to resolve.
      await tester.pumpAndSettle();
    });

    testWidgetsOnAndroid("doesn't overscroll when dragging up", (tester) async {
      final scrollController = ScrollController();

      await tester //
          .createDocument()
          .withSingleParagraph()
          .withScrollController(scrollController)
          .pump();

      // Jump to the bottom.
      scrollController.jumpTo(scrollController.position.maxScrollExtent);

      // Drag an arbitrary amount of pixels from the bottom of the reader.
      final dragGesture = await tester.dragByFrameCount(
        startLocation: tester.getRect(find.byType(SuperReader)).bottomCenter - const Offset(0, 5),
        totalDragOffset: const Offset(0, -200.0),
      );

      // Ensure we don't scroll.
      expect(scrollController.offset, scrollController.position.maxScrollExtent);

      // End the gesture.
      await dragGesture.up();

      // Wait for the long-press timer to resolve.
      await tester.pumpAndSettle();
    });

    testWidgetsOnIos('overscrolls when dragging down', (tester) async {
      final scrollController = ScrollController();

      await tester //
          .createDocument()
          .withSingleParagraph()
          .withScrollController(scrollController)
          .pump();

      // Ensure the scrollview didn't start scrolled.
      expect(scrollController.offset, 0);

      // Drag an arbitrary amount of pixels a few pixels below the top of the reader.
      final dragGesture = await tester.dragByFrameCount(
        startLocation: tester.getRect(find.byType(SuperReader)).topCenter + const Offset(0, 5),
        totalDragOffset: const Offset(0, 80.0),
      );

      // Ensure we are overscrolling while holding the pointer down.
      await tester.pumpAndSettle();
      expect(scrollController.offset, lessThan(0.0));

      // Release the pointer to end the gesture.
      await dragGesture.up();

      // Wait for the long-press timer to resolve.
      await tester.pumpAndSettle();

      // Ensure the we scrolled back to the top.
      expect(scrollController.offset, 0.0);
    });

    testWidgetsOnIos('overscrolls when dragging up', (tester) async {
      final scrollController = ScrollController();

      await tester //
          .createDocument()
          .withSingleParagraph()
          .withScrollController(scrollController)
          .pump();

      // Jump to the bottom.
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pumpAndSettle();

      // Drag an arbitrary amount of pixels from the bottom of the reader.
      // The gesture starts with an arbitrary margin from the bottom.
      final dragGesture = await tester.dragByFrameCount(
        startLocation: tester.getRect(find.byType(SuperReader)).bottomCenter - const Offset(0, 5),
        totalDragOffset: const Offset(0, -200.0),
      );

      // Ensure we are overscrolling while holding the pointer down.
      await tester.pumpAndSettle();
      expect(scrollController.offset, greaterThan(scrollController.position.maxScrollExtent));

      // Release the pointer to end the gesture.
      await dragGesture.up();

      // Wait for the long-press timer to resolve.
      await tester.pumpAndSettle();

      // Ensure the we scrolled back to the end.
      expect(scrollController.offset, scrollController.position.maxScrollExtent);
    });

    group("when all content fits in the viewport", () {
      testWidgetsOnDesktop(
        "trackpad doesn't scroll content",
        (tester) async {
          tester.view.physicalSize = const Size(800, 600);

          final isScrollUp = _scrollDirectionVariant.currentValue == _ScrollDirection.up;

          await tester //
              .createDocument()
              .withCustomContent(
                paragraphThenHrThenParagraphDoc()
                  ..insertNodeAt(
                    0,
                    ParagraphNode(
                      id: Editor.createNodeId(),
                      text: AttributedText('Document #1'),
                      metadata: {
                        'blockType': header1Attribution,
                      },
                    ),
                  ),
              )
              .pump();

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          // Perform a fling on the reader to attemp scrolling.
          await tester.trackpadFling(
            find.byType(SuperReader),
            Offset(0.0, isScrollUp ? 100 : -100),
            300,
          );

          await tester.pump();

          // Ensure SuperReader is not scrolling.
          expect(scrollState.position.activity?.isScrolling, false);
        },
        variant: _scrollDirectionVariant,
      );

      testWidgetsOnDesktop(
        "mouse scroll wheel doesn't scroll content",
        (tester) async {
          tester.view.physicalSize = const Size(800, 600);

          final isScrollUp = _scrollDirectionVariant.currentValue == _ScrollDirection.up;

          await tester //
              .createDocument()
              .withCustomContent(
                paragraphThenHrThenParagraphDoc()
                  ..insertNodeAt(
                    0,
                    ParagraphNode(
                      id: Editor.createNodeId(),
                      text: AttributedText('Document #1'),
                      metadata: {
                        'blockType': header1Attribution,
                      },
                    ),
                  ),
              )
              .pump();

          final scrollState = tester.state<ScrollableState>(find.byType(Scrollable));

          final Offset scrollEventLocation = tester.getCenter(find.byType(SuperReader));
          final TestPointer testPointer = TestPointer(1, PointerDeviceKind.mouse);

          // Send initial pointer event to set the location for subsequent pointer scroll events.
          await tester.sendEventToBinding(testPointer.hover(scrollEventLocation));

          // Send pointer scroll event to start scrolling.
          await tester.sendEventToBinding(
            testPointer.scroll(
              Offset(
                0.0,
                isScrollUp ? 100 : -100.0,
              ),
            ),
          );

          await tester.pump();

          // Ensure SuperReader is not scrolling.
          expect(scrollState.position.activity!.isScrolling, false);
        },
        variant: _scrollDirectionVariant,
      );
    });

    group("with ancestor scrollable", () {
      testWidgetsOnMobile('scrolling and holding the pointer doesn\'t change selection', (tester) async {
        final scrollController = ScrollController();

        // Pump a reader inside a CustomScrollView without enough room to display
        // the whole content.
        await tester
            .createDocument() //
            .withLongTextContent()
            .withEditorSize(const Size(200, 200))
            .insideCustomScrollView()
            .withScrollController(scrollController)
            .pump();

        // Ensure the scrollview didn't start scrolled.
        expect(scrollController.offset, 0);

        final scrollableRect = tester.getRect(find.byType(CustomScrollView));

        const dragFrameCount = 10;
        final dragAmountPerFrame = scrollableRect.height / dragFrameCount;

        // Drag from the bottom all the way up to the top of the scrollable.
        final dragGesture = await tester.startGesture(scrollableRect.bottomCenter - const Offset(0, 1));
        for (int i = 0; i < dragFrameCount; i += 1) {
          await dragGesture.moveBy(Offset(0, -dragAmountPerFrame));
          await tester.pump();
        }

        // The reader supports long press to select.
        // Wait long enough to make sure  this gesture wasn't confused with a long press.
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 1));

        // Ensure we scrolled and didn't change the selection.
        expect(scrollController.offset, greaterThan(0));
        expect(SuperReaderInspector.findDocumentSelection(), isNull);

        await dragGesture.up();
        await dragGesture.removePointer();
      });

      testWidgetsOnMobile('scrolling and releasing the pointer doesn\'t change selection after gesture ended',
          (tester) async {
        final scrollController = ScrollController();

        // Pump a reader inside a CustomScrollView without enough room to display
        // the whole content.
        await tester
            .createDocument() //
            .withLongTextContent()
            .withEditorSize(const Size(200, 200))
            .insideCustomScrollView()
            .withScrollController(scrollController)
            .pump();

        // Ensure the scrollview didn't start scrolled.
        expect(scrollController.offset, 0);

        final scrollableRect = tester.getRect(find.byType(CustomScrollView));

        const dragFrameCount = 10;
        final dragAmountPerFrame = scrollableRect.height / dragFrameCount;

        // Drag from the bottom all the way up to the top of the scrollable.
        final dragGesture = await tester.startGesture(scrollableRect.bottomCenter - const Offset(0, 1));
        for (int i = 0; i < dragFrameCount; i += 1) {
          await dragGesture.moveBy(Offset(0, -dragAmountPerFrame));
          await tester.pump();
        }

        // Stop the scrolling gesture.
        await dragGesture.up();
        await dragGesture.removePointer();
        await tester.pump();

        // The reader supports long press to select.
        // Wait long enough to make sure  this gesture wasn't confused with a long press.
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 1));

        // Ensure we scrolled and didn't change the selection.
        expect(scrollController.offset, greaterThan(0));
        expect(SuperReaderInspector.findDocumentSelection(), isNull);
      });

      testWidgetsOnAndroid("doesn't overscroll when dragging down", (tester) async {
        final scrollController = ScrollController();

        await tester
            .createDocument()
            .withSingleParagraph()
            .insideCustomScrollView()
            .withScrollController(scrollController)
            .pump();

        // Ensure the scrollview didn't start scrolled.
        expect(scrollController.offset, 0);

        // Drag an arbitrary amount of pixels from the top of the reader.
        final dragGesture = await tester.dragByFrameCount(
          startLocation: tester.getRect(find.byType(SuperReader)).topCenter + const Offset(0, 5),
          totalDragOffset: const Offset(0, 400.0),
        );

        // Ensure we don't scroll.
        expect(scrollController.offset, 0);

        // End the gesture.
        await dragGesture.up();

        // Wait for the long-press timer to resolve.
        await tester.pumpAndSettle();
      });

      testWidgetsOnAndroid("doesn't overscroll when dragging up", (tester) async {
        final scrollController = ScrollController();

        // Pump a reader inside a CustomScrollView without enough room to display
        // the whole content.
        await tester
            .createDocument()
            .withSingleParagraph()
            .withEditorSize(const Size(200, 200))
            .insideCustomScrollView()
            .withScrollController(scrollController)
            .pump();

        // Jump to the bottom.
        scrollController.jumpTo(scrollController.position.maxScrollExtent);

        // Drag an arbitrary amount of pixels from the bottom of the reader.
        final dragGesture = await tester.dragByFrameCount(
          startLocation: tester.getRect(find.byType(CustomScrollView)).bottomCenter - const Offset(0, 5),
          totalDragOffset: const Offset(0, -400.0),
        );

        // Ensure we don't scroll.
        expect(scrollController.offset, scrollController.position.maxScrollExtent);

        // End the gesture.
        await dragGesture.up();

        // Wait for the long-press timer to resolve.
        await tester.pumpAndSettle();
      });

      testWidgetsOnIos('overscrolls when dragging down', (tester) async {
        final scrollController = ScrollController();

        await tester
            .createDocument() //
            .withLongTextContent()
            .insideCustomScrollView()
            .withScrollController(scrollController)
            .pump();

        // Ensure the scrollview didn't start scrolled.
        expect(scrollController.offset, 0);

        // Drag an arbitrary amount, smaller than the reader size.
        final dragGesture = await tester.dragByFrameCount(
          startLocation: tester.getRect(find.byType(CustomScrollView)).topCenter + const Offset(0, 5),
          totalDragOffset: const Offset(0, 80.0),
        );

        // Ensure we are overscrolling while holding the pointer down.
        await tester.pumpAndSettle();
        expect(scrollController.offset, lessThan(0.0));

        // Release the pointer to end the gesture.
        await dragGesture.up();

        // Wait for the long-press timer to resolve.
        await tester.pumpAndSettle();

        // Ensure the we scrolled back to the top.
        expect(scrollController.offset, 0.0);
      });

      testWidgetsOnIos('overscrolls when dragging up', (tester) async {
        final scrollController = ScrollController();

        // Pump a reader inside a CustomScrollView without enough room to display
        // the whole content.
        await tester
            .createDocument() //
            .withLongTextContent()
            .withEditorSize(const Size(200, 200))
            .insideCustomScrollView()
            .withScrollController(scrollController)
            .pump();

        // Jump to the bottom.
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
        await tester.pumpAndSettle();

        // Drag up an arbitrary amount, smaller than the reader size.
        final dragGesture = await tester.dragByFrameCount(
          startLocation: tester.getRect(find.byType(CustomScrollView)).bottomCenter - const Offset(0, 5),
          totalDragOffset: const Offset(0, -100.0),
        );

        // Ensure we are overscrolling while holding the pointer down.
        await tester.pumpAndSettle();
        expect(scrollController.offset, greaterThan(scrollController.position.maxScrollExtent));

        // Release the pointer to end the gesture.
        await dragGesture.up();

        // Wait for the long-press timer to resolve.
        await tester.pumpAndSettle();

        // Ensure the we scrolled back to the end.
        expect(scrollController.offset, scrollController.position.maxScrollExtent);
      });

      group("when hovering over editor", () {
        testWidgets("scroll down doesn't scroll the page untill editor's scrollable content is consumed",
            (tester) async {
          await tester.pumpWidget(const ScrollingWithinAncestorScrollable());

          final pageScrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);

          // Find editor's direct ancestor scrollable
          final superEditorScrollable = tester.state<ScrollableState>(
            find.ancestor(of: find.byType(SuperReader), matching: find.byType(Scrollable)).first,
          );

          final TestPointer testPointer = TestPointer(1, PointerDeviceKind.mouse);

          // Hover to the editor's center.
          testPointer.hover(
            tester.getCenter(
              find.ancestor(of: find.byType(SuperReader), matching: find.byType(Scrollable)).first,
            ),
          );

          await tester.sendEventToBinding(
            testPointer.scroll(
              Offset(0, superEditorScrollable.position.maxScrollExtent),
            ),
          );

          // Ensure editor's is scrolled to the bottom.
          expect(
            superEditorScrollable.position.pixels,
            superEditorScrollable.position.maxScrollExtent,
          );

          // Ensure page isn't scrolled.
          expect(pageScrollable.position.pixels, 0);

          // Scroll down within the page.
          await tester.sendEventToBinding(
            testPointer.scroll(
              const Offset(0, 200),
            ),
          );

          // Ensure page is scrolled.
          expect(pageScrollable.position.pixels, greaterThan(0));
        });

        testWidgets(
          "scroll up doesn't scroll the page untill editor's scrollable content is consumed",
          (tester) async {
            await tester.pumpWidget(const ScrollingWithinAncestorScrollable());

            final pageScrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);

            // Find editor's direct ancestor scrollable.
            final superEditorScrollable = tester.state<ScrollableState>(
              find.ancestor(of: find.byType(SuperReader), matching: find.byType(Scrollable)).first,
            );

            // Scroll the editor all the way to the bottom.
            superEditorScrollable.position.jumpTo(superEditorScrollable.position.maxScrollExtent);

            final TestPointer testPointer = TestPointer(1, PointerDeviceKind.mouse);

            // Scroll an arbitrary amount in the page before we attempt to scroll the editor.
            pageScrollable.position.jumpTo(100);

            // Hover to the editor's center.
            testPointer.hover(
              tester.getCenter(
                find.ancestor(of: find.byType(SuperReader), matching: find.byType(Scrollable)).first,
              ),
            );

            // Scroll the editor all the way to the top.
            await tester.sendEventToBinding(
              testPointer.scroll(
                Offset(0, -superEditorScrollable.position.maxScrollExtent),
              ),
            );

            // Ensure editor's is scrolled all the way to the top.
            expect(
              superEditorScrollable.position.pixels,
              0,
            );

            // Ensure page isn't scrolled any further than initial page scroll.
            expect(pageScrollable.position.pixels, 100);

            // Scroll back to the page top.
            await tester.sendEventToBinding(
              testPointer.scroll(
                const Offset(0, -100),
              ),
            );

            // Ensure page is scrolled all the way to the top.
            expect(pageScrollable.position.pixels, 0);
          },
        );
      });
    });
  });
}

/// Creates a [SuperReader] experience within an ancestor scrollable
/// with scrollable editor content.
class ScrollingWithinAncestorScrollable extends StatelessWidget {
  const ScrollingWithinAncestorScrollable({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return ListView(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                width: double.infinity,
                child: const Placeholder(
                  child: Center(
                    child: Text("Content"),
                  ),
                ),
              ),
              SizedBox(
                height: 350,
                child: ListView(
                  children: [
                    SuperReader(
                      document: longTextDoc(),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height,
                width: double.infinity,
                child: const Placeholder(
                  child: Center(
                    child: Text("Content"),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Creates a [SuperEditor] experience within an ancestor scrollable
/// with scrollable editor content.
Future<void> _pumpSuperEditorWithinScrollable(WidgetTester tester) async {
  await tester.createDocument().withLongTextContent().withCustomWidgetTreeBuilder((superReader) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) {
          return ListView(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                width: double.infinity,
                child: const Placeholder(
                  child: Center(
                    child: Text("Content"),
                  ),
                ),
              ),
              SizedBox(
                height: 350,
                child: ListView(
                  children: [
                    superReader,
                  ],
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height,
                width: double.infinity,
                child: const Placeholder(
                  child: Center(
                    child: Text("Content"),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }).pump();
}

final _scrollDirectionVariant = ValueVariant<_ScrollDirection>({
  _ScrollDirection.up,
  _ScrollDirection.down,
});

enum _ScrollDirection {
  up,
  down;
}
