import 'package:flutter/material.dart';
import '../../models/property.dart';
import '../../models/utility_provider.dart';
import '../../database/database_helper.dart';

class Step1PropertySelection extends StatefulWidget {
  final Function(Property) onPropertySelected;
  final Property? selectedProperty;

  const Step1PropertySelection({
    super.key,
    required this.onPropertySelected,
    this.selectedProperty,
  });

  @override
  State<Step1PropertySelection> createState() => _Step1PropertySelectionState();
}

class _Step1PropertySelectionState extends State<Step1PropertySelection> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Property> _properties = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() => _isLoading = true);
    
    try {
      final properties = await _databaseHelper.getProperties();
      setState(() {
        _properties = properties.where((p) => p.isActive).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading properties: $e')),
        );
      }
    }
  }

  List<Property> get _filteredProperties {
    if (_searchQuery.isEmpty) return _properties;
    
    return _properties.where((property) {
      return property.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             property.address.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             property.state.displayName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildSearchBar(),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildPropertyList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.home_work,
              color: Theme.of(context).primaryColor,
              size: 32,
            ),
            const SizedBox(width: 12),
            const Text(
              'Select Property',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the property for which you want to calculate expenses',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search properties...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.1),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildPropertyList() {
    final filteredProperties = _filteredProperties;
    
    if (filteredProperties.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: filteredProperties.length,
      itemBuilder: (context, index) {
        final property = filteredProperties[index];
        final isSelected = widget.selectedProperty?.id == property.id;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: isSelected ? 4 : 1,
          color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: isSelected 
                  ? Theme.of(context).primaryColor 
                  : Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Icon(
                Icons.home_work,
                color: isSelected ? Colors.white : Theme.of(context).primaryColor,
              ),
            ),
            title: Text(
              property.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Theme.of(context).primaryColor : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(property.address),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      property.state.displayName,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.meeting_room,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${property.totalRooms} rooms',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            trailing: isSelected
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  )
                : const Icon(Icons.arrow_forward_ios),
            onTap: () => widget.onPropertySelected(property),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No properties found' : 'No properties match your search',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty 
                ? 'Add properties first to start calculating expenses'
                : 'Try adjusting your search terms',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Navigate to add property screen
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Property'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
