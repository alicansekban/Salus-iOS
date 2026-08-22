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
/// Takes the `ProfileDao` because Koin's `get()` hands out the one instance the container built:
/// the composition root already holds a `ProfileDao`, and building a second one here would give
/// the app two DAOs over the same database where Android has one.
public func makeProfileRepository(
    profileDao: ProfileDao,
    clock: any SalusClock
) -> any ProfileRepository {
    ProfileRepositoryImpl(profileDao: profileDao, clock: clock)
}

/// The same repository for a caller that holds only the database — a test building a small graph,
/// where the DAO is a detail of the wiring rather than something worth naming.
public func makeProfileRepository(
    database: SalusDatabase,
    clock: any SalusClock
) -> any ProfileRepository {
    makeProfileRepository(profileDao: ProfileDao(database: database), clock: clock)
}
