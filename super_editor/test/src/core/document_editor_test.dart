import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import '../../super_editor/document_test_tools.dart';
import '../../super_editor/test_documents.dart';

void main() {
  group('DocumentEditor', () {
    group('editing', () {
      // TODO: test that Document gets notified of changes before Composer, because selection
      //       is based on document structure, not the other way around

      test('throws exception when there is no command for a given request', () {
        final editor = Editor(
          editables: {
            Editor.documentKey: MutableDocument(
              nodes: [ParagraphNode(id: Editor.createNodeId(), text: AttributedText(text: ""))],
            ),
          },
          requestHandlers: [],
        );

        expectLater(() {
          editor.execute([const InsertCharacterAtCaretRequest(character: "a")]);
        }, throwsException);
      });

      test('executes a single command', () {
        final editorPieces = _createStandardEditor(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
        DocumentChangeLog? changeLog;
        editorPieces.document.addListener((newChangeLog) {
          changeLog = newChangeLog;
        });

        editorPieces.editor.execute([const InsertCharacterAtCaretRequest(character: "a")]);

        expect(changeLog, isNotNull);
        expect(changeLog!.changes.length, 2);
        expect(changeLog!.changes.first, isA<NodeChangeEvent>());
        expect(changeLog!.changes.last, isA<SelectionChangeEvent>());
      });

      test('executes a series of commands', () {
        final editorPieces = _createStandardEditor(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
        int changeLogCount = 0;
        int changeEventCount = 0;
        editorPieces.document.addListener((newChangeLog) {
          changeLogCount += 1;
          changeEventCount += newChangeLog.changes.length;
        });

        editorPieces.editor
          ..execute([const InsertCharacterAtCaretRequest(character: "H")])
          ..execute([const InsertCharacterAtCaretRequest(character: "e")])
          ..execute([const InsertCharacterAtCaretRequest(character: "l")])
          ..execute([const InsertCharacterAtCaretRequest(character: "l")])
          ..execute([const InsertCharacterAtCaretRequest(character: "o")]);

        expect(changeLogCount, 5);
        expect(changeEventCount, 10); // 2 events per character insertion
        expect((editorPieces.document.getNodeAt(0) as ParagraphNode).text.text, "Hello");
      });

      test('executes multiple expanding commands', () {
        // This test ensures that if one command expands into multiple commands,
        // and those commands expand to additional commands, the overall command
        // order is what we expect.
        DocumentChangeLog? changeLog;
        final document = MutableDocument(
          nodes: [ParagraphNode(id: Editor.createNodeId(), text: AttributedText(text: ""))],
        )..addListener((newLog) {
            changeLog = newLog;
          });

        final composer = DocumentComposer(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: [
            (request) => request is _ExpandingCommandRequest ? _ExpandingCommand(request) : null,
          ],
          listeners: [
            FunctionalEditorChangeListener(
              document.onDocumentChange,
            ),
            FunctionalEditorChangeListener(
              composer.selectionComponent.onEditorChange,
            ),
          ],
        );

        editor.execute([
          const _ExpandingCommandRequest(
            generationId: 0,
            batchId: 0,
            newCommandCount: 3,
            levelsOfGeneration: 2,
          ),
        ]);

        // Ensure that the commands printed the number and spacing that we expected,
        // given the expansion order.
        //
        // Each value is "(a.b)" where "a" is the generation, and "b" is the batch ID
        // within the generation. The output should look like a depth first tree
        // traversal.
        final paragraph = document.getNodeAt(0) as ParagraphNode;
        expect(
          paragraph.text.text,
          '''(0.0)
  (1.0)
    (2.0)
    (2.1)
    (2.2)
  (1.1)
    (2.0)
    (2.1)
    (2.2)
  (1.2)
    (2.0)
    (2.1)
    (2.2)''',
        );

        expect(changeLog, isNotNull);
        expect(changeLog!.changes.length, 13 * 2); // 13 commands * 2 events per command
      });

      test('runs reactions after a command', () {
        int reactionCount = 0;

        final document = MutableDocument(
          nodes: [ParagraphNode(id: Editor.createNodeId(), text: AttributedText(text: ""))],
        );

        final composer = DocumentComposer(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: defaultRequestHandlers,
          reactionPipeline: [
            FunctionalEditReaction((editorContext, requestDispatcher, changeList) {
              reactionCount += 1;
            }),
          ],
          listeners: [
            FunctionalEditorChangeListener(
              document.onDocumentChange,
            ),
            FunctionalEditorChangeListener(
              composer.selectionComponent.onEditorChange,
            ),
          ],
        );

        editor.execute([
          InsertTextRequest(
            documentPosition: const DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
            textToInsert: "H",
            attributions: const {},
          ),
        ]);

        // Ensure that our reaction ran after the requested command.
        expect(reactionCount, 1);
      });

      test('interrupts back-to-back commands to run a reaction', () {
        final document = MutableDocument(
          nodes: [ParagraphNode(id: "1", text: AttributedText(text: ""))],
        );

        final composer = DocumentComposer(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );

        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: defaultRequestHandlers,
          reactionPipeline: [
            FunctionalEditReaction((editorContext, requestDispatcher, changeList) {
              TextInsertionEvent? insertEEvent;
              for (final change in changeList) {
                if (change is! TextInsertionEvent) {
                  continue;
                }

                insertEEvent = change.text.endsWith("e") ? change : null;
              }

              if (insertEEvent == null) {
                return;
              }

              // Insert "ll" after "e" to get "Hello" when all the commands are done.
              requestDispatcher.execute([
                InsertTextRequest(
                  documentPosition: DocumentPosition(
                    nodeId: insertEEvent.nodeId,
                    nodePosition: TextNodePosition(offset: insertEEvent.offset + 1), // +1 for "e"
                  ),
                  textToInsert: "ll",
                  attributions: {},
                ),
              ]);
            }),
          ],
          listeners: [
            FunctionalEditorChangeListener(
              document.onDocumentChange,
            ),
            FunctionalEditorChangeListener(
              composer.selectionComponent.onEditorChange,
            ),
          ],
        );

        editor
          ..execute([
            InsertTextRequest(
              documentPosition: const DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 0),
              ),
              textToInsert: "H",
              attributions: const {},
            ),
          ])
          ..execute([
            InsertTextRequest(
              documentPosition: const DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 1),
              ),
              textToInsert: "e",
              attributions: const {},
            ),
          ])
          ..execute([
            InsertTextRequest(
              documentPosition: const DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 4),
              ),
              textToInsert: "o",
              attributions: const {},
            ),
          ]);

        // Ensure that our reaction ran in the middle of the requests.
        expect((document.nodes.first as TextNode).text.text, "Hello");
      });

      test('reactions receive a change list with events from earlier reactions', () {
        final document = MutableDocument(
          nodes: [ParagraphNode(id: "1", text: AttributedText(text: ""))],
        );

        final composer = DocumentComposer(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );

        final editor = Editor(
          editables: {
            Editor.documentKey: document,
            Editor.composerKey: composer,
          },
          requestHandlers: defaultRequestHandlers,
          reactionPipeline: [
            // Reaction 1 causes a change
            FunctionalEditReaction((editorContext, requestDispatcher, changeList) {
              TextInsertionEvent? insertHEvent;
              for (final change in changeList) {
                if (change is! TextInsertionEvent) {
                  continue;
                }

                insertHEvent = change.text == "H" ? change : null;
              }

              if (insertHEvent == null) {
                return;
              }

              // Insert "e" after "H".
              requestDispatcher.execute([
                InsertTextRequest(
                  documentPosition: DocumentPosition(
                    nodeId: insertHEvent.nodeId,
                    nodePosition: TextNodePosition(offset: insertHEvent.offset),
                  ),
                  textToInsert: "e",
                  attributions: {},
                ),
              ]);
            }),
            // Reaction 2 verifies that it sees the change event from reaction 1.
            FunctionalEditReaction((editorContext, requestDispatcher, changeList) {
              TextInsertionEvent? insertEEvent;
              for (final change in changeList) {
                if (change is! TextInsertionEvent) {
                  continue;
                }

                insertEEvent = change.text == "e" ? change : null;
              }

              expect(insertEEvent, isNotNull, reason: "Reaction 2 didn't receive the change from reaction 1");
            }),
          ],
          listeners: [
            FunctionalEditorChangeListener(
              document.onDocumentChange,
            ),
            FunctionalEditorChangeListener(
              composer.selectionComponent.onEditorChange,
            ),
          ],
        );

        editor.execute([
          InsertTextRequest(
            documentPosition: const DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
            textToInsert: "H",
            attributions: const {},
          ),
        ]);

        // If execution makes it here then the test is successful.
      });

      test('inserts character at caret', () {
        final editorPieces = _createStandardEditor(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );

        editorPieces.editor
          ..execute([
            InsertTextRequest(
              documentPosition: const DocumentPosition(
                nodeId: "1",
                nodePosition: TextNodePosition(offset: 0),
              ),
              textToInsert: 'H',
              attributions: const {},
            ),
          ])
          ..execute([
            const ChangeSelectionRequest(
              DocumentSelection.collapsed(
                position: DocumentPosition(
                  nodeId: "1",
                  nodePosition: TextNodePosition(offset: 1),
                ),
              ),
              SelectionChangeType.place,
              "test",
            ),
          ]);

        // Ensure the character was inserted, and the caret moved forward.
        expect((editorPieces.document.getNodeAt(0) as TextNode).text.text, "H");
        expect(editorPieces.composer.selectionComponent.selection, isNotNull);
        expect(
          editorPieces.composer.selectionComponent.selection,
          const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 1),
            ),
          ),
        );
      });

      test('inserts new paragraph node at caret', () {
        final editorPieces = _createStandardEditor(
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
        int changeLogCount = 0;
        int changeEventCount = 0;
        final document = editorPieces.document;
        document.addListener((newChangeLog) {
          changeLogCount += 1;
          changeEventCount += newChangeLog.changes.length;
        });

        editorPieces.editor.execute([
          SplitParagraphRequest(
            nodeId: "1",
            splitPosition: const TextNodePosition(offset: 0),
            newNodeId: "2",
            replicateExistingMetadata: true,
          )
        ]);

        // Verify content changes.
        expect(document.nodes.length, 2);
        expect(document.getNodeAt(0)!.id, "1");
        expect(document.getNodeAt(1)!.id, "2");

        // Verify reported changes.
        expect(changeLogCount, 1);
        // Expected events:
        //  - submit paragraph intention: start
        //  - node change event: node 1
        //  - node inserted event
        //  - selection change event
        //  - submit paragraph intention: end
        expect(changeEventCount, 5);
      });

      test('moves a document node to a new position', () {
        final editorPieces = _createStandardEditor(
          initialDocument: longTextDoc(),
          initialSelection: const DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: "1",
              nodePosition: TextNodePosition(offset: 0),
            ),
          ),
        );
        int changeLogCount = 0;
        int changeEventCount = 0;
        final document = editorPieces.document;
        document.addListener((newChangeLog) {
          changeLogCount += 1;
          changeEventCount += newChangeLog.changes.length;
        });

        editorPieces.editor.execute([const MoveNodeRequest(nodeId: "1", newIndex: 2)]);

        // Verify final node indices.
        expect(document.getNodeAt(0)!.id, "2");
        expect(document.getNodeAt(1)!.id, "3");
        expect(document.getNodeAt(2)!.id, "1");

        // Verify reported changes.
        expect(changeLogCount, 1);
        expect(changeEventCount, 3); // 3 nodes were moved
      });
    });
  });
}

// TODO: check how/why this is different from default_document_editor.dart method called createDefaultDocumentEditor()
StandardEditorPieces _createStandardEditor({
  MutableDocument? initialDocument,
  DocumentSelection? initialSelection,
}) {
  final document = initialDocument ?? singleParagraphEmptyDoc();

  final composer = DocumentComposer(initialSelection: initialSelection);
  final editor = Editor(
    editables: {
      Editor.documentKey: document,
      Editor.composerKey: composer,
    },
    requestHandlers: defaultRequestHandlers,
    reactionPipeline: [
      LinkifyReaction(),
      UnorderedListItemConversionReaction(),
      OrderedListItemConversionReaction(),
      BlockquoteConversionReaction(),
      HorizontalRuleConversionReaction(),
      ImageUrlConversionReaction(),
    ],
    listeners: [
      FunctionalEditorChangeListener(
        document.onDocumentChange,
      ),
      FunctionalEditorChangeListener(
        composer.selectionComponent.onEditorChange,
      ),
    ],
  );

  return StandardEditorPieces(document, composer, editor);
}

/// Request that runs a command, which spawns more commands, based on the
/// given [newCommandCount] and [levelsOfGeneration].
///
/// This request, and its command, are used to test the command spawning and
/// ordering behavior of [Editor] without finding real commands that
/// exemplify the necessary spawning behavior.
class _ExpandingCommandRequest implements EditRequest {
  const _ExpandingCommandRequest({
    required this.generationId,
    required this.batchId,
    required this.newCommandCount,
    required this.levelsOfGeneration,
  });

  /// The generation of this request, e.g., `0` for the first generation,
  /// `1` for the second, etc.
  final int generationId;

  /// The ID of this request within its generation batch.
  ///
  /// If three requests are created within a newly spawned generation, then the
  /// first request to be generated will be given ID `0`, the second `1`, etc.
  final int batchId;

  /// The number of new commands that this request will generate (breadth of a tree).
  final int newCommandCount;

  /// The number of generations of commands that this request will generate (depth
  /// of a tree).
  final int levelsOfGeneration;
}

class _ExpandingCommand implements EditCommand {
  const _ExpandingCommand(this.request);

  final _ExpandingCommandRequest request;

  @override
  void execute(EditorContext context, CommandExecutor executor) {
    final document = context.find<Document>(Editor.documentKey);
    final paragraph = document.getNodeAt(0) as ParagraphNode;

    executor.executeCommand(
      InsertTextCommand(
        documentPosition: DocumentPosition(
          nodeId: paragraph.id,
          nodePosition: TextNodePosition(offset: paragraph.text.text.length),
        ),
        textToInsert:
            "${request.generationId > 0 ? "\n" : ""}${List.filled(request.generationId, "  ").join()}(${request.generationId}.${request.batchId})",
        attributions: {},
      ),
    );

    if (request.levelsOfGeneration > 0) {
      for (int i = 0; i < request.newCommandCount; i += 1) {
        executor.executeCommand(
          _ExpandingCommand(
            _ExpandingCommandRequest(
              generationId: request.generationId + 1, // +1 for next generation
              batchId: i, // i'th member of this generation
              newCommandCount: request.newCommandCount,
              levelsOfGeneration: request.levelsOfGeneration - 1, // -1 generations to go
            ),
          ),
        );
      }
    }
  }
}
