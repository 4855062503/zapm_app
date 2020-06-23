import 'package:flutter/material.dart';
import 'package:edit_distance/edit_distance.dart';

import 'libzap.dart';
import 'widgets.dart';

typedef WordIndexCallback = void Function(int); 
typedef WordsCallback = void Function(List<String>); 

extension ExtendedIterable<E> on Iterable<E> {
  /// Like Iterable<T>.map but callback have index as second argument
  Iterable<T> mapIndex<T>(T f(E e, int i)) {
    var i = 0;
    return this.map((e) => f(e, i++));
  }

  void forEachIndex(void f(E e, int i)) {
    var i = 0;
    this.forEach((e) => f(e, i++));
  }
}

class Bip39Words extends StatelessWidget {
  Bip39Words(this.words, this.validBip39, this.onWordPressed, {this.rowSize = 4}) : super();

  final List<String> words;
  final bool validBip39;
  final WordIndexCallback onWordPressed;
  final int rowSize;

  static Bip39Words fromString(String words) {
    return Bip39Words(words.split(' '), false, (i){});
  }

  @override
  Widget build(BuildContext context) {
    var rows = List<List<String>>();
    var row = List<String>();
    for (var word in words) {
      row.add(word);
      if (row.length >= rowSize) {
        rows.add(row);
        row = List<String>();
      }
    }
    if (row.length > 0)
      rows.add(row);
    return Column(
      children: rows.mapIndex((item, rowIndex) {
        return Row(children: item.mapIndex((item, index) {
          return Container(
            width: 65, height: 30, padding: EdgeInsets.all(1),
            child: ButtonTheme(buttonColor: validBip39 ? zapgreen.withAlpha(198) : Colors.white, padding: EdgeInsets.all(2),
            child: RaisedButton(
              child: Row(children: [
                Text(' ${rowIndex * rowSize + index + 1}', style: TextStyle(color: zapblacklight, fontSize: 8)),
                Expanded(
                  child: Center(child: Text(item, style: TextStyle(fontSize: 11)))
                )]),
              onPressed: () => onWordPressed(rowIndex * rowSize + index))));
          }).toList()
        );
      }).toList()
    );
  }
}

class Bip39Entry extends StatefulWidget {
  Bip39Entry(this.onWordsUpdate) : super();

  final WordsCallback onWordsUpdate;

  @override
  _Bip39EntryState createState() => _Bip39EntryState();
}

class _Bip39EntryState extends State<Bip39Entry> {
  var _textController = TextEditingController();
  var _levenshtein = Levenshtein();
  List<String> _wordlist = LibZap().mnemonicWordlist();
  List<String> _mnemonicWords = List<String>();
  var _candidates = ['', '', ''];
  var _validBip39 = false;

  void clearCandidates() {
    for (var i = 0; i < _candidates.length; i += 1)
      _candidates[i] = '';
  }

  void inputChanged(String value) {
    // all bip39 words are lowercase
    value = value.toLowerCase();

    // initialize our potential candidate variables
    var c = List<String>(_candidates.length);
    c.forEachIndex((e, i) => c[i] = '');
    var d = List<double>(_candidates.length);
    d.forEachIndex((e, i) => d[i] = 1.0);
    var prefixMatched = 0;

    for (var item in _wordlist) {
      // if the item matches exactly then add it and reset
      if (value == item) {
        setState(() {
          clearCandidates();
          _mnemonicWords.add(value);
          updateWords();
          _textController.text = '';
        });
        return;
      }

      // if we have filled the candidates with prefix matched values then dont bother checking for more
      if (prefixMatched >= c.length)
        continue;

      // check for words that match the prefix exactly
      if (value.isNotEmpty && item.length > value.length && value == item.substring(0, value.length)) {
        c[prefixMatched] = item;
        prefixMatched++;
        continue;
      }

      // check for words that are close in terms of levenshtein distance
      var dist = _levenshtein.normalizedDistance(value, item);
      if (dist > 0.4)
        continue;
      // we make prefix matched candidates higher priority then levenshtein distance matched candidates by initializing the candidateIndex here
      var candidateIndex = prefixMatched;
      while (candidateIndex < c.length) {
        if (dist < d[candidateIndex]) {
          d[candidateIndex] = dist;
          c[candidateIndex] = item;
          break;
        }
        candidateIndex++;
      }
    }
    setState(() {
      _candidates = c;      
    });
  }

  void wordRemove(int index) {
    setState(() {
      _mnemonicWords.removeAt(index);
      updateWords();
    });
  }

  void updateWords() {
    _validBip39 = LibZap().mnemonicCheck(_mnemonicWords.join(' '));
    widget.onWordsUpdate(_mnemonicWords);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          autofocus: true,
          controller: _textController,
          decoration: InputDecoration(labelText: "Recovery Words",),
          onChanged: inputChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List<Widget>.generate(_candidates.length, (index) {
            return ButtonTheme(minWidth: 40, height: 25, buttonColor: zapyellow.withAlpha(198),
              child: RaisedButton(child: Text(_candidates[index]), onPressed: () => inputChanged(_candidates[index]))
            ); 
          })
        ),
        Bip39Words(_mnemonicWords, _validBip39, (index) => wordRemove(index))
      ],
    );
  }
}
