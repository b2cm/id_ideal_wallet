import 'package:flutter/material.dart';

class TopUp extends StatefulWidget {
  const TopUp(
      {super.key, required this.onTopUpSats, required this.onTopUpFiat});

  final void Function(int, String) onTopUpSats;
  final void Function(int) onTopUpFiat;

  @override
  State<TopUp> createState() => _TopUpState();
}

class _TopUpState extends State<TopUp> {
  final List<bool> _selectedReceiveOption = <bool>[true, false];

  // textfield values
  final TextEditingController _amountControllerSats = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  final TextEditingController _amountControllerFiat = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Container(
            padding: const EdgeInsets.all(16),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              ToggleButtons(
                direction: Axis.horizontal,
                onPressed: (int index) {
                  setState(() {
                    // The button that is tapped is set to true, and the others to false.
                    for (int i = 0; i < _selectedReceiveOption.length; i++) {
                      _selectedReceiveOption[i] = i == index;
                    }
                  });
                },
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                selectedBorderColor: const Color.fromARGB(255, 255, 86, 86),
                selectedColor: Colors.white,
                fillColor: const Color.fromARGB(255, 255, 86, 86),
                color: const Color.fromARGB(255, 255, 86, 86),
                borderColor: const Color.fromARGB(255, 255, 86, 86),
                borderWidth: 2,
                constraints: const BoxConstraints(
                  minHeight: 30.0,
                  minWidth: 80.0,
                ),
                isSelected: _selectedReceiveOption,
                children: const <Widget>[
                  Text('Crypto', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Fiat', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 20),
              _selectedReceiveOption[0]
                  ?
                  // toogle button to switch between fiat and sats
                  TextField(
                      controller: _amountControllerSats,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Betrag in Satoshi',
                      ),
                    )
                  : // toogle button to switch between fiat and sats
                  TextField(
                      controller: _amountControllerFiat,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Betrag in Euro',
                      ),
                    ),
              if (_selectedReceiveOption[0]) const SizedBox(height: 20),
              if (_selectedReceiveOption[0])
                TextField(
                  controller: _memoController,
                  maxLines: 8, //or null
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Memo',
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => {
                  if (_selectedReceiveOption[0])
                    {
                      widget.onTopUpSats(int.parse(_amountControllerSats.text),
                          _memoController.text)
                    }
                  else
                    {widget.onTopUpFiat(int.parse(_amountControllerFiat.text))}
                },
                child: _selectedReceiveOption[0]
                    ? const Text('Zahlung anfordern')
                    : const Text('Aufladen'),
              ),
            ])));
  }
}
