import '../entities/local_entities.dart';

abstract class LocalRepository {
  Future<LocalProfile?> getMyLocalProfile(String profileId);
  Future<void> upsertLocalProfile(String profileId, Map<String, dynamic> data);
  Future<void> setLocalPreferences(String profileId,
      {required List<String> activities, required List<String> interests});

  Future<List<LocalCandidate>> getCandidates({int limit = 20});

  Future<List<LocalConnection>> getMyLocalConnections(String myId,
      {LocalConnectionStatus? status});
  Future<LocalConnection?> getLocalConnectionBetween(
      String myId, String otherId);
  Future<void> sendLocalRequest(String receiverId);
  Future<void> respondToLocalRequest(String connectionId,
      {required bool accept});

  Future<List<MeetupSuggestion>> getMeetupsForConnection(
      String localConnectionId);
  Future<void> suggestMeetup(Map<String, dynamic> data);
  Future<void> respondToMeetup(String meetupId, {required bool accept});
}
