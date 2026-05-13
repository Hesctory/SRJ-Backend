using SRJBackend.Application.DTOs;
using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Queries;

public class LookupQueries : ILookupQueries
{
    private readonly IGenderRepository _genderRepo;
    private readonly IDocumentTypeRepository _documentTypeRepo;
    private readonly IReligionRepository _religionRepo;
    private readonly ICivilStateRepository _civilStateRepo;
    private readonly ILanguageRepository _languageRepo;
    private readonly IEthnicSelfIdentificationRepository _ethnicRepo;
    private readonly IChildbirthTypeRepository _childbirthTypeRepo;
    private readonly IFamiliarRelationshipTypeRepository _familiarRelationshipTypeRepo;
    private readonly IDisabilityTypeRepository _disabilityTypeRepo;
    private readonly IDisabilityDegreeRepository _disabilityDegreeRepo;
    private readonly ILevelOfEducationRepository _levelOfEducationRepo;
    private readonly IRucStateRepository _rucStateRepo;

    public LookupQueries(
        IGenderRepository genderRepo,
        IDocumentTypeRepository documentTypeRepo,
        IReligionRepository religionRepo,
        ICivilStateRepository civilStateRepo,
        ILanguageRepository languageRepo,
        IEthnicSelfIdentificationRepository ethnicRepo,
        IChildbirthTypeRepository childbirthTypeRepo,
        IFamiliarRelationshipTypeRepository familiarRelationshipTypeRepo,
        IDisabilityTypeRepository disabilityTypeRepo,
        IDisabilityDegreeRepository disabilityDegreeRepo,
        ILevelOfEducationRepository levelOfEducationRepo,
        IRucStateRepository rucStateRepo)
    {
        _genderRepo = genderRepo;
        _documentTypeRepo = documentTypeRepo;
        _religionRepo = religionRepo;
        _civilStateRepo = civilStateRepo;
        _languageRepo = languageRepo;
        _ethnicRepo = ethnicRepo;
        _childbirthTypeRepo = childbirthTypeRepo;
        _familiarRelationshipTypeRepo = familiarRelationshipTypeRepo;
        _disabilityTypeRepo = disabilityTypeRepo;
        _disabilityDegreeRepo = disabilityDegreeRepo;
        _levelOfEducationRepo = levelOfEducationRepo;
        _rucStateRepo = rucStateRepo;
    }

    public Task<List<GenderDTO>> GetGendersAsync() => _genderRepo.GetAllAsync();
    public Task<List<DocumentTypeDTO>> GetDocumentTypesAsync() => _documentTypeRepo.GetAllAsync();
    public Task<List<ReligionDTO>> GetReligionsAsync() => _religionRepo.GetAllAsync();
    public Task<List<CivilStateDTO>> GetCivilStatesAsync() => _civilStateRepo.GetAllAsync();
    public Task<List<LanguageDTO>> GetLanguagesAsync() => _languageRepo.GetAllAsync();
    public Task<List<EthnicSelfIdentificationDTO>> GetEthnicSelfIdentificationsAsync() => _ethnicRepo.GetAllAsync();
    public Task<List<ChildbirthTypeDTO>> GetChildbirthTypesAsync() => _childbirthTypeRepo.GetAllAsync();
    public Task<List<FamiliarRelationshipTypeDTO>> GetFamiliarRelationshipTypesAsync() => _familiarRelationshipTypeRepo.GetAllAsync();
    public Task<List<DisabilityTypeDTO>> GetDisabilityTypesAsync() => _disabilityTypeRepo.GetAllAsync();
    public Task<List<DisabilityDegreeDTO>> GetDisabilityDegreesAsync() => _disabilityDegreeRepo.GetAllAsync();
    public Task<List<LevelOfEducationDTO>> GetLevelOfEducationsAsync() => _levelOfEducationRepo.GetAllAsync();
    public Task<List<RucStateDTO>> GetRucStatesAsync() => _rucStateRepo.GetAllAsync();
}
