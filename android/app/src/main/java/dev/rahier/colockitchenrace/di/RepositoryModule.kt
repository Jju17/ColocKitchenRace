package dev.rahier.colockitchenrace.di

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import dev.rahier.colockitchenrace.data.repository.*
import dev.rahier.colockitchenrace.data.repository.impl.*
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindAuthRepository(impl: AuthRepositoryImpl): AuthRepository

    @Binds
    @Singleton
    abstract fun bindCohouseRepository(impl: CohouseRepositoryImpl): CohouseRepository

    @Binds
    @Singleton
    abstract fun bindCKRGameRepository(impl: CKRGameRepositoryImpl): CKRGameRepository

    @Binds
    @Singleton
    abstract fun bindChallengeRepository(impl: ChallengeRepositoryImpl): ChallengeRepository

    @Binds
    @Singleton
    abstract fun bindChallengeResponseRepository(impl: ChallengeResponseRepositoryImpl): ChallengeResponseRepository

    @Binds
    @Singleton
    abstract fun bindNewsRepository(impl: NewsRepositoryImpl): NewsRepository

    @Binds
    @Singleton
    abstract fun bindStripeRepository(impl: StripeRepositoryImpl): StripeRepository

    @Binds
    @Singleton
    abstract fun bindUserRepository(impl: UserRepositoryImpl): UserRepository
}
