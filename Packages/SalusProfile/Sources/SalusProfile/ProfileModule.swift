// Ported 1:1 from
// `core/profile/src/main/kotlin/com/alicansekban/salus/core/profile/di/ProfileModule.kt`.
//
// Koin's `profileModule` is a Gradle-module-level factory that hands out the interface and keeps
// the implementation internal (`ProfileModule.kt:7-9`:
// `single<ProfileRepository> { ProfileRepositoryImpl(get(), get()) }`). There is no container in
// this tree, so the twin is the function the container would have called — same reach, same
// hiding: `ProfileRepositoryImpl` stays internal, and so does the `ProfileDao` it is built on.

import SalusCommon
import SalusDatabase

/// The single `ProfileRepository` a caller outside this module can get.
///
/// The `ProfileDao` is built here rather than taken as a parameter because it is Koin's `get()`
/// on Android: a detail of the wiring, not something a feature ever names. The database and the
/// clock are the two dependencies the app owns.
public func makeProfileRepository(
    database: SalusDatabase,
    clock: any SalusClock
) -> any ProfileRepository {
    ProfileRepositoryImpl(profileDao: ProfileDao(database: database), clock: clock)
}
