namespace SRJBackend.Domain.ValueObjects;

public record EducationalDemographics
{
    public int NativeLanguageId { get; }
    public int? EthnicSelfIdentificationId { get; }
    public List<int>? SecondLanguageIds { get; }

    public EducationalDemographics(int nativeLanguageId, int? ethnicSelfIdentificationId, List<int>? secondLanguageIds)
    {
        if (nativeLanguageId <= 0)
            throw new ArgumentException("Native language is required.", nameof(nativeLanguageId));

        NativeLanguageId = nativeLanguageId;
        EthnicSelfIdentificationId = ethnicSelfIdentificationId;
        SecondLanguageIds = secondLanguageIds;
    }
}
