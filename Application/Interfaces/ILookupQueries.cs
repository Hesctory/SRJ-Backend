using SRJBackend.Application.DTOs;

namespace SRJBackend.Application.Interfaces;

public interface ILookupQueries
{
    Task<List<GenderDTO>> GetGendersAsync();
    Task<List<DocumentTypeDTO>> GetDocumentTypesAsync();
    Task<List<ReligionDTO>> GetReligionsAsync();
    Task<List<CivilStateDTO>> GetCivilStatesAsync();
    Task<List<LanguageDTO>> GetLanguagesAsync();
    Task<List<EthnicSelfIdentificationDTO>> GetEthnicSelfIdentificationsAsync();
    Task<List<ChildbirthTypeDTO>> GetChildbirthTypesAsync();
    Task<List<FamiliarRelationshipTypeDTO>> GetFamiliarRelationshipTypesAsync();
    Task<List<DisabilityTypeDTO>> GetDisabilityTypesAsync();
    Task<List<DisabilityDegreeDTO>> GetDisabilityDegreesAsync();
    Task<List<LevelOfEducationDTO>> GetLevelOfEducationsAsync();
    Task<List<RucStateDTO>> GetRucStatesAsync();
}
